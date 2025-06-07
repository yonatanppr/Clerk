import PDFKit
import SwiftUI
import SwiftData
import DocumentScannerView
import QuickLook


struct FileSystemView: View {
    @Environment(\.modelContext) private var modelContext
    let currentFolder: FolderItem?
    
    // State for managing alerts
    @State private var showingCreateFolderAlert = false
    @State private var newFolderName = ""
    @State private var showingRenameFolderAlert = false
    @State private var folderToRename: FolderItem?
    @State private var renamedFolderName = ""
    @State private var showingDeleteConfirmationAlert = false
    @State private var folderMarkedForDeletion: FolderItem?
    @State private var isShowingScanner = false
    
    // QuickLook state
    @State private var selectedFileURL: URL?
    @State private var isShowingQuickLook = false
    
    // Query for subfolders and files
    @Query var items: [FolderItem]
    @Query var files: [FileItem]
    
    init(currentFolder: FolderItem?) {
        self.currentFolder = currentFolder
        
        if let currentFolder {
            let currentFolderID = currentFolder.persistentModelID
            self._items = Query(filter: #Predicate<FolderItem> { folderItem in
                folderItem.parent?.persistentModelID == currentFolderID
            }, sort: [SortDescriptor(\FolderItem.name)])
            self._files = Query(filter: #Predicate<FileItem> { fileItem in
                fileItem.parent?.persistentModelID == currentFolderID
            }, sort: [SortDescriptor(\FileItem.name)])
        } else {
            self._items = Query(filter: #Predicate<FolderItem> { folderItem in
                folderItem.parent == nil
            }, sort: [SortDescriptor(\FolderItem.name)])
            self._files = Query(filter: #Predicate<FileItem> { fileItem in
                fileItem.parent == nil
            }, sort: [SortDescriptor(\FileItem.name)])
        }
    }
    
    var body: some View {
        ZStack {
            List {
                Section(header: Text("Folders")) {
                    ForEach(items) { folder in
                        NavigationLink(value: folder) {
                            HStack {
                                Image(systemName: "folder")
                                Text(folder.name)
                            }
                        }
                        .contextMenu {
                            Button("Rename") {
                                folderToRename = folder
                                renamedFolderName = folder.name
                                showingRenameFolderAlert = true
                            }
                            Button("Delete", role: .destructive) {
                                requestDeleteConfirmation(for: folder)
                            }
                        }
                    }
                    .onDelete(perform: deleteFoldersAtIndexSet)
                }
                
                Section(header: Text("Files")) {
                    ForEach(files) { file in
                        Button {
                            if FileManager.default.fileExists(atPath: file.fullURL.path) {
                                print("Opening file at: \(file.fullURL.path)")
                                selectedFileURL = file.fullURL
                                isShowingQuickLook = true
                            } else {
                                print("File does not exist at path: \(file.fullURL.path)")
                            }
                        } label: {
                            HStack {
                                Image(systemName: "doc.richtext")
                                    .foregroundColor(.blue)
                                Text(file.name)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            Button(role: .destructive) {
                                // TODO: Implement file deletion
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        isShowingScanner = true
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 28, weight: .medium))
                            .frame(width: 60, height: 60)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                            .shadow(color: .gray.opacity(0.6), radius: 8, x: 0, y: 4)
                    }
                    .accessibilityLabel("Scan new document")
                    Spacer()
                }
                .padding(.bottom, 40)
            }
            .ignoresSafeArea(.keyboard)
        }
        .navigationTitle(currentFolder?.name ?? "Clerk")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    newFolderName = ""
                    showingCreateFolderAlert = true
                } label: {
                    Label("Create Folder", systemImage: "plus.circle.fill")
                }
            }
        }
        .alert("New Folder", isPresented: $showingCreateFolderAlert) {
            TextField("Folder Name", text: $newFolderName)
            Button("Create") {
                createFolder(name: newFolderName)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for the new folder.")
        }
        .alert("Rename Folder", isPresented: $showingRenameFolderAlert) {
            TextField("New Name", text: $renamedFolderName)
            Button("Rename") {
                if let folder = folderToRename {
                    renameFolder(folder, newName: renamedFolderName)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter the new name for '\(folderToRename?.name ?? "")'.")
        }
        .navigationDestination(for: FolderItem.self) { folder in
            FileSystemView(currentFolder: folder)
        }
        .alert("Confirm Deletion", isPresented: $showingDeleteConfirmationAlert, presenting: folderMarkedForDeletion) { folderToDelete in
            Button("Delete", role: .destructive) {
                performDelete(folder: folderToDelete)
            }
            Button("Cancel", role: .cancel) {}
        } message: { folderToDelete in
            Text("Are you sure you want to delete '\(folderToDelete.name)'? All its contents will also be deleted.")
        }
        .sheet(isPresented: $isShowingScanner) {
            DocumentScannerView { result in
                switch result {
                case .success(let scannedImages):
                    saveScansAsPDF(scannedImages)
                case .failure(let error):
                    print("Scan failed: \(error.localizedDescription)")
                }
            }
        }
        .sheet(isPresented: $isShowingQuickLook) {
            if let url = selectedFileURL {
                QuickLookPreview(url: url)
            }
        }
    }
    
    // MARK: - Save Scans as PDF
    private func saveScansAsPDF(_ images: [UIImage]) {
        guard !images.isEmpty else { return }
        let pdfData = NSMutableData()
        let pdfConsumer = CGDataConsumer(data: pdfData as CFMutableData)!

        // Use first image size as the PDF page size, or default to standard if unavailable
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, nil) else { return }

        for image in images {
            let pageSize = CGRect(origin: .zero, size: image.size)
            var pageMediaBox = pageSize
            pdfContext.beginPage(mediaBox: &pageMediaBox)
            if let cgImage = image.cgImage {
                pdfContext.draw(cgImage, in: pageSize)
            }
            pdfContext.endPage()
        }
        pdfContext.closePDF()

        let filename = "Scan_\(Int(Date().timeIntervalSince1970)).pdf"
        let newFile = FileItem(name: filename, parent: currentFolder)
        
        // Ensure the parent directory exists before saving
        newFile.ensureParentDirectoryExists()
        
        // Save the PDF file
        do {
            try pdfData.write(to: newFile.fullURL, options: .atomic)
            modelContext.insert(newFile)
            try modelContext.save()
            print("Successfully saved file '\(filename)' to folder: \(currentFolder?.name ?? "root")")
            print("File saved at path: \(newFile.fullURL.path)")
        } catch {
            print("Failed to save file: \(error.localizedDescription)")
        }
    }

    private func createFolder(name: String) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let newFolder = FolderItem(name: name, parent: currentFolder)
        modelContext.insert(newFolder)
        do {
            try modelContext.save() // Explicitly save the context
        } catch {
            // In a production app, you might want to show an alert to the user
            print("Failed to save new folder: \(error.localizedDescription)")
        }
    }

    private func renameFolder(_ folder: FolderItem, newName: String) {
        guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        folder.name = newName
        // SwiftData automatically saves changes to managed objects.
    }

    private func requestDeleteConfirmation(for folder: FolderItem) {
        folderMarkedForDeletion = folder
        showingDeleteConfirmationAlert = true
    }

    private func performDelete(folder: FolderItem) {
        modelContext.delete(folder) // Cascade delete will handle subfolders
        // Optionally, add error handling with try? modelContext.save() if experiencing issues
    }

    private func deleteFoldersAtIndexSet(offsets: IndexSet) {
        // Standard swipe-to-delete usually acts on one item.
        // If multiple were possible, a different confirmation strategy might be needed.
        offsets.map { items[$0] }.forEach(requestDeleteConfirmation)
    }
}

// Add QuickLook preview support
struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(url: url)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        
        init(url: URL) {
            self.url = url
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return url as QLPreviewItem
        }
    }
}
