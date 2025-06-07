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
                        FolderRowView(
                            folder: folder,
                            onRename: {
                                folderToRename = folder
                                renamedFolderName = folder.name
                                showingRenameFolderAlert = true
                            },
                            onDelete: {
                                requestDeleteConfirmation(for: folder)
                            }
                        )
                    }
                    .onDelete(perform: deleteFoldersAtIndexSet)
                }
                
                Section(header: Text("Files")) {
                    ForEach(files) { file in
                        FileRowView(file: file) {
                            if FileManager.default.fileExists(atPath: file.fullURL.path) {
                                print("Opening file at: \(file.fullURL.path)")
                                selectedFileURL = file.fullURL
                                isShowingQuickLook = true
                            } else {
                                print("File does not exist at path: \(file.fullURL.path)")
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
                    let filename = "Scan_\(Int(Date().timeIntervalSince1970)).pdf"
                    PDFGenerator.generatePDF(from: scannedImages, fileName: filename, parent: currentFolder, modelContext: modelContext)
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
    
    private func createFolder(name: String) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let newFolder = FolderItem(name: name, parent: currentFolder)
        modelContext.insert(newFolder)
        do {
            try modelContext.save()
        } catch {
            print("Failed to save new folder: \(error.localizedDescription)")
        }
    }
    
    private func renameFolder(_ folder: FolderItem, newName: String) {
        guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        folder.name = newName
    }
    
    private func requestDeleteConfirmation(for folder: FolderItem) {
        folderMarkedForDeletion = folder
        showingDeleteConfirmationAlert = true
    }
    
    private func performDelete(folder: FolderItem) {
        modelContext.delete(folder)
    }
    
    private func deleteFoldersAtIndexSet(offsets: IndexSet) {
        offsets.map { items[$0] }.forEach(requestDeleteConfirmation)
    }
}
