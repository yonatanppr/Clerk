import PDFKit
import SwiftUI
import SwiftData
import DocumentScannerView

struct FileSystemView: View {
    @Environment(\.modelContext) private var modelContext
    let currentFolder: FolderItem? // The folder whose contents are being displayed, nil for root

    // State for managing alerts
    @State private var showingCreateFolderAlert = false
    @State private var newFolderName = ""

    @State private var showingRenameFolderAlert = false
    @State private var folderToRename: FolderItem?
    @State private var renamedFolderName = ""

    @State private var showingDeleteConfirmationAlert = false
    @State private var folderMarkedForDeletion: FolderItem?
    @State private var isShowingScanner = false // State to control scanner presentation

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
        let documentsFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsFolder.appendingPathComponent(filename)
        pdfData.write(to: fileURL, atomically: true)

        let newFile = FileItem(name: filename, url: fileURL, parent: currentFolder)
        modelContext.insert(newFile)

        do {
            try modelContext.save()
            print("Successfully saved file '\(filename)' to folder: \(currentFolder?.name ?? "root")")
            print("File saved at path: \(fileURL.path)")
        } catch {
            print("Failed to save FileItem: \(error.localizedDescription)")
        }
    }


    // Query for subfolders of the currentFolder or root folders if currentFolder is nil
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
            // Layer 1: The List of folders and files
            List {
                Section(header: Text("Folders")) {
                    ForEach(items) { folder in
                        NavigationLink(value: folder) { // Navigate to the selected folder
                            HStack {
                                Image(systemName: "folder")
                                Text(folder.name)
                            }
                        }
                        .contextMenu { // Options for each folder
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
                    .onDelete(perform: deleteFoldersAtIndexSet) // Swipe to delete
                }
                Section(header: Text("Files")) {
                    ForEach(files) { file in
                        HStack {
                            Image(systemName: "doc.richtext")
                            Text(file.name)
                        }
                    }
                }
            }

            // Layer 2: The "Scan Document" Button
            VStack {
                Spacer() // Pushes the button towards the bottom

                HStack {
                    Spacer() // Centers the button horizontally
                    Button {
                        isShowingScanner = true // Present the DocumentScannerView
                    } label: {
                        Image(systemName: "camera.fill") // Icon-only for a circular button
                            .font(.system(size: 28, weight: .medium))
                            .frame(width: 60, height: 60) // Define a fixed size for the circle
                            .background(Color.blue)       // Prominent background color
                            .foregroundColor(.white)       // Icon color
                            .clipShape(Circle())           // Make it circular
                            .shadow(color: .gray.opacity(0.6), radius: 8, x: 0, y: 4) // Add a shadow for depth
                    }
                    .accessibilityLabel("Scan new document") // For accessibility
                    Spacer() // Centers the button horizontally
                }
                .padding(.bottom, 40) // Adjust this padding to position in the "bottom quarter"
            }
            .ignoresSafeArea(.keyboard) // Ensures the button isn't affected by the keyboard appearing
        }
        .navigationTitle(currentFolder?.name ?? "Clerk")
        .toolbar { // Toolbar for other items, like "Create Folder"
            ToolbarItem(placement: .navigationBarTrailing) {
                // The "Create Folder" button remains in the toolbar
                Button {
                    newFolderName = "" // Clear previous input
                    showingCreateFolderAlert = true
                } label: {
                    Label("Create Folder", systemImage: "plus.circle.fill")
                }
            }
        }
        .alert("New Folder", isPresented: $showingCreateFolderAlert) { // Alerts remain attached
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
        // This handles navigation to sub-folders.
        // When a FolderItem is selected, a new FileSystemView is pushed for that folder.
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
        // Sheet for DocumentScannerView
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

#Preview {
    // This MainActor.assumeIsolated block helps set up SwiftData for previews correctly.
    MainActor.assumeIsolated {
        let config = ModelConfiguration(isStoredInMemoryOnly: true) // Use in-memory store for previews
        let container = try! ModelContainer(for: FolderItem.self, configurations: config)

        // Sample Data for Preview
        let context = container.mainContext
        let workDocs = FolderItem(name: "Work Documents")
        context.insert(workDocs)
        let projectAlpha = FolderItem(name: "Project Alpha", parent: workDocs)
        context.insert(projectAlpha)
        let personalDocs = FolderItem(name: "Personal")
        context.insert(personalDocs)

        return NavigationStack { // Previews need a NavigationStack if the view uses navigation features
            FileSystemView(currentFolder: nil) // Start at the root for the preview
        }
        .modelContainer(container) // Provide the model container to the preview
    }
}
