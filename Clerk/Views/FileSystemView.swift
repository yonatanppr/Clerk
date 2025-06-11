import PDFKit
import SwiftUI
import SwiftData
import DocumentScannerView
import QuickLook


struct FileSystemView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var folders: [FolderItem]
    @Query private var files: [FileItem]
    
    let currentFolder: FolderItem?
    @Binding var navigationPath: NavigationPath // For programmatic navigation
    
    // State for managing alerts
    @State private var showingCreateFolderAlert = false
    @State private var newFolderName = ""
    @State private var showingRenameFolderAlert = false
    @State private var folderToRename: FolderItem?
    @State private var renamedFolderName = ""
    @State private var showingDeleteConfirmationAlert = false
    @State private var folderMarkedForDeletion: FolderItem?
    @State private var isShowingScanner = false
    @State private var currentDocument: ScannedDocument?
    @State private var isShowingDocumentReview = false
    @State private var isProcessingDocument = false
    
    // Multi-select state
    @State private var isMultiSelectMode = false
    @State private var selectedFiles: Set<FileItem> = []
    
    // QuickLook state
    @State private var selectedFileURL: URL?
    @State private var isShowingQuickLook = false

    init(currentFolder: FolderItem?, navigationPath: Binding<NavigationPath>) {
        self.currentFolder = currentFolder
        self._navigationPath = navigationPath

        if let currentFolder {
            let currentFolderID = currentFolder.persistentModelID
            self._folders = Query(filter: #Predicate<FolderItem> { folderItem in
                folderItem.parent?.persistentModelID == currentFolderID
            }, sort: [SortDescriptor(\FolderItem.name)])
            self._files = Query(filter: #Predicate<FileItem> { fileItem in
                fileItem.parent?.persistentModelID == currentFolderID
            }, sort: [SortDescriptor(\FileItem.name)])
        } else {
            self._folders = Query(filter: #Predicate<FolderItem> { folderItem in
                folderItem.parent == nil
            }, sort: [SortDescriptor(\FolderItem.name)])
            self._files = Query(filter: #Predicate<FileItem> { fileItem in
                fileItem.parent == nil
            }, sort: [SortDescriptor(\FileItem.name)])
        }
    }
    
    var body: some View {
        VStack(spacing: 0) { // Use a VStack to arrange BreadcrumbView and the List
            // Display BreadcrumbView if we are inside a folder
            if let folder = currentFolder {
                BreadcrumbView(
                    path: folder.getPath(),
                    onNavigate: { tappedFolder in
                        // Navigate back to the tapped folder
                        let fullCurrentPath = folder.getPath()
                        if let targetIndex = fullCurrentPath.firstIndex(where: { $0.id == tappedFolder.id }) {
                            let itemsToPop = (fullCurrentPath.count - 1) - targetIndex
                            if itemsToPop > 0 {
                                navigationPath.removeLast(itemsToPop)
                            }
                        }
                    },
                    onNavigateToRoot: {
                        // Navigate to the root by clearing the navigation path
                        navigationPath.removeLast(navigationPath.count)
                    }
                )
                .padding(.horizontal) // Add some horizontal padding around the breadcrumb bar
                .padding(.bottom, 4) // Space between breadcrumbs and list
            }

            ZStack {
                List {
                    Section(header: Text("Folders")) {
                        ForEach(folders) { folder in
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
                            FileRowView(
                                file: file,
                                isSelected: selectedFiles.contains(file),
                                onTap: {
                                    if isMultiSelectMode {
                                        if selectedFiles.contains(file) {
                                            selectedFiles.remove(file)
                                        } else {
                                            selectedFiles.insert(file)
                                        }
                                    } else {
                                        if FileManager.default.fileExists(atPath: file.fullURL.path) {
                                            print("Opening file at: \(file.fullURL.path)")
                                            selectedFileURL = file.fullURL
                                            isShowingQuickLook = true
                                        } else {
                                            print("File does not exist at path: \(file.fullURL.path)")
                                        }
                                    }
                                }
                            )
                        }
                    }
                }
                .background(Color.clear) // Remove the drop target background

                
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
        }
        .navigationTitle(currentFolder?.name ?? "Clerk")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !files.isEmpty {
                    Button {
                        isMultiSelectMode.toggle()
                        if !isMultiSelectMode {
                            selectedFiles.removeAll()
                        }
                    } label: {
                        Text(isMultiSelectMode ? "Done" : "Select")
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if !isMultiSelectMode {
                    Button {
                        newFolderName = ""
                        showingCreateFolderAlert = true
                    } label: {
                        Label("Create Folder", systemImage: "plus.circle.fill")
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if isMultiSelectMode && !selectedFiles.isEmpty {
                    Button(role: .destructive) {
                        showingDeleteConfirmationAlert = true
                    } label: {
                        Label("Delete Selected", systemImage: "trash")
                    }
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
        .alert("Confirm Deletion", isPresented: $showingDeleteConfirmationAlert, presenting: folderMarkedForDeletion) { folderToDelete in
            Button("Delete", role: .destructive) {
                performDelete(folder: folderToDelete)
            }
            Button("Cancel", role: .cancel) {}
        } message: { folderToDelete in
            Text("Are you sure you want to delete '\(folderToDelete.name)'? All its contents will also be deleted.")
        }
        .alert("Delete Selected Files", isPresented: $showingDeleteConfirmationAlert) {
            Button("Delete", role: .destructive) {
                for file in selectedFiles {
                    FileService.deleteFile(file, modelContext: modelContext)
                }
                selectedFiles.removeAll()
                isMultiSelectMode = false
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \(selectedFiles.count) selected file(s)?")
        }
        .sheet(isPresented: $isShowingScanner) {
            DocumentScannerView { result in
                switch result {
                case .success(let scannedImages):
                    Task {
                        isProcessingDocument = true
                        let document = ScannedDocument(images: scannedImages)
                        currentDocument = document
                        
                        do {
                            let (summary, title, folderSuggestion, documentType, requiredAction) = try await LLMService.analyzeDocument(
                                images: scannedImages,
                                existingFolders: Array(folders)
                            )
                            document.llmSummary = summary
                            document.suggestedTitle = title
                            document.suggestedFolder = folderSuggestion.suggestedFolder
                            document.shouldCreateNewFolder = folderSuggestion.shouldCreateNewFolder
                            document.newFolderName = folderSuggestion.newFolderName
                            document.documentType = documentType
                            document.requiredAction = requiredAction
                            document.processingStatus = .completed
                            isShowingDocumentReview = true
                        } catch {
                            document.processingStatus = .failed(error)
                            print("LLM processing failed: \(error.localizedDescription)")
                        }
                        
                        isProcessingDocument = false
                    }
                case .failure(let error):
                    print("Scan failed: \(error.localizedDescription)")
                }
            }
        }
        .sheet(isPresented: $isShowingDocumentReview) {
            if let document = currentDocument {
                DocumentReviewView(document: document, parent: currentFolder)
                    .modelContext(modelContext)
            }
        }
        .overlay {
            if isProcessingDocument {
                VStack {
                    ProgressView("Analyzing document...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.4))
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
        offsets.map { folders[$0] }.forEach(requestDeleteConfirmation)
    }
}
