//
//  FileSystemView.swift
//  Clerk
//
//  Created by Yonatan Pepper on 01.06.25.
//

import SwiftUI
import SwiftData

// MARK: - Folder Row View
struct FolderRowView: View {
    let folder: FolderItem
    let onRename: (FolderItem) -> Void
    let onDelete: (FolderItem) -> Void
    
    var body: some View {
        NavigationLink(value: folder) {
            HStack {
                Image(systemName: "folder")
                Text(folder.name)
            }
        }
        .contextMenu {
            Button("Rename") {
                onRename(folder)
            }
            Button("Delete", role: .destructive) {
                onDelete(folder)
            }
        }
    }
}

// MARK: - Document Row View
struct DocumentRowView: View {
    let document: DocumentItem
    let onSelect: (DocumentItem) -> Void
    let onDelete: (DocumentItem) -> Void
    
    var body: some View {
        Button {
            onSelect(document)
        } label: {
            HStack {
                Image(systemName: "doc.text")
                Text(document.name)
            }
        }
        .contextMenu {
            Button("Delete", role: .destructive) {
                onDelete(document)
            }
        }
    }
}

// MARK: - Scan Button View
struct ScanButtonView: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "camera.fill")
                .font(.system(size: 28, weight: .medium))
                .frame(width: 60, height: 60)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(Circle())
                .shadow(color: .gray.opacity(0.6), radius: 8, x: 0, y: 4)
        }
        .accessibilityLabel("Scan new document")
    }
}

// MARK: - File List Content View
struct FileListContentView: View {
    let folders: [FolderItem]
    let documents: [DocumentItem]
    let onFolderRename: (FolderItem) -> Void
    let onFolderDelete: (FolderItem) -> Void
    let onDocumentSelect: (DocumentItem) -> Void
    let onDocumentDelete: (DocumentItem) -> Void
    let onFoldersDelete: (IndexSet) -> Void
    let onDocumentsDelete: (IndexSet) -> Void
    
    var body: some View {
        List {
            Section("Folders") {
                ForEach(folders) { folder in
                    FolderRowView(
                        folder: folder,
                        onRename: onFolderRename,
                        onDelete: onFolderDelete
                    )
                }
                .onDelete(perform: onFoldersDelete)
            }
            
            Section("Documents") {
                ForEach(documents) { document in
                    DocumentRowView(
                        document: document,
                        onSelect: onDocumentSelect,
                        onDelete: onDocumentDelete
                    )
                }
                .onDelete(perform: onDocumentsDelete)
            }
        }
    }
}

// MARK: - Alert Modifiers View
struct AlertModifiersView: ViewModifier {
    @Binding var showingCreateFolderAlert: Bool
    @Binding var newFolderName: String
    let onCreateFolder: (String) -> Void
    @Binding var showingRenameFolderAlert: Bool
    @Binding var renamedFolderName: String
    let folderToRename: FolderItem?
    let onRenameFolder: (FolderItem, String) -> Void
    @Binding var showingDeleteConfirmationAlert: Bool
    let folderMarkedForDeletion: FolderItem?
    let onDeleteFolder: (FolderItem) -> Void
    
    func body(content: Content) -> some View {
        content
            .alert("New Folder", isPresented: $showingCreateFolderAlert) {
                TextField("Folder Name", text: $newFolderName)
                Button("Create") {
                    onCreateFolder(newFolderName)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a name for the new folder.")
            }
            .alert("Rename Folder", isPresented: $showingRenameFolderAlert) {
                TextField("New Name", text: $renamedFolderName)
                Button("Rename") {
                    if let folder = folderToRename {
                        onRenameFolder(folder, renamedFolderName)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter the new name for '\(folderToRename?.name ?? "")'.")
            }
            .alert("Confirm Deletion", isPresented: $showingDeleteConfirmationAlert, presenting: folderMarkedForDeletion) { folderToDelete in
                Button("Delete", role: .destructive) {
                    onDeleteFolder(folderToDelete)
                }
                Button("Cancel", role: .cancel) {}
            } message: { folderToDelete in
                Text("Are you sure you want to delete '\(folderToDelete.name)'? All its contents will also be deleted.")
            }
    }
}

// MARK: - View Extension
extension View {
    func alertModifiers(
        showingCreateFolderAlert: Binding<Bool>,
        newFolderName: Binding<String>,
        onCreateFolder: @escaping (String) -> Void,
        showingRenameFolderAlert: Binding<Bool>,
        renamedFolderName: Binding<String>,
        folderToRename: FolderItem?,
        onRenameFolder: @escaping (FolderItem, String) -> Void,
        showingDeleteConfirmationAlert: Binding<Bool>,
        folderMarkedForDeletion: FolderItem?,
        onDeleteFolder: @escaping (FolderItem) -> Void
    ) -> some View {
        self.modifier(AlertModifiersView(
            showingCreateFolderAlert: showingCreateFolderAlert,
            newFolderName: newFolderName,
            onCreateFolder: onCreateFolder,
            showingRenameFolderAlert: showingRenameFolderAlert,
            renamedFolderName: renamedFolderName,
            folderToRename: folderToRename,
            onRenameFolder: onRenameFolder,
            showingDeleteConfirmationAlert: showingDeleteConfirmationAlert,
            folderMarkedForDeletion: folderMarkedForDeletion,
            onDeleteFolder: onDeleteFolder
        ))
    }
}

// MARK: - Main FileSystemView
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
    @State private var selectedDocument: DocumentItem? = nil
    @State private var showingDocumentPreview = false

    // Query for subfolders and documents
    @Query private var folders: [FolderItem]
    @Query private var documents: [DocumentItem]

    init(currentFolder: FolderItem?) {
        self.currentFolder = currentFolder
        
        if let currentFolder {
            let currentFolderID = currentFolder.persistentModelID
            self._folders = Query(filter: #Predicate<FolderItem> { folderItem in
                folderItem.parent?.persistentModelID == currentFolderID
            }, sort: [SortDescriptor(\FolderItem.name)])
            
            self._documents = Query(filter: #Predicate<DocumentItem> { document in
                document.parent?.persistentModelID == currentFolderID
            }, sort: [SortDescriptor(\DocumentItem.name)])
        } else {
            self._folders = Query(filter: #Predicate<FolderItem> { folderItem in
                folderItem.parent == nil
            }, sort: [SortDescriptor(\FolderItem.name)])
            
            self._documents = Query(filter: #Predicate<DocumentItem> { document in
                document.parent == nil
            }, sort: [SortDescriptor(\DocumentItem.name)])
        }
    }

    var body: some View {
        ZStack {
            FileListContentView(
                folders: folders,
                documents: documents,
                onFolderRename: handleRename,
                onFolderDelete: requestDeleteConfirmation,
                onDocumentSelect: { selectedDocument = $0; showingDocumentPreview = true },
                onDocumentDelete: deleteDocument,
                onFoldersDelete: deleteFoldersAtIndexSet,
                onDocumentsDelete: deleteDocumentsAtIndexSet
            )

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ScanButtonView(action: { isShowingScanner = true })
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
        .navigationDestination(for: FolderItem.self) { folder in
            FileSystemView(currentFolder: folder)
        }
        .fullScreenCover(isPresented: $isShowingScanner) {
            DocumentScannerView(onSave: { imageData in
                saveScannedDocument(imageData: imageData)
            })
        }
        .sheet(isPresented: $showingDocumentPreview) {
            if let document = selectedDocument {
                DocumentPreviewView(document: document)
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
    }

    private func handleRename(_ folder: FolderItem) {
        folderToRename = folder
        renamedFolderName = folder.name
        showingRenameFolderAlert = true
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
    
    private func deleteDocumentsAtIndexSet(offsets: IndexSet) {
        offsets.map { documents[$0] }.forEach { document in
            deleteDocument(document)
        }
    }
    
    private func deleteDocument(_ document: DocumentItem) {
        modelContext.delete(document)
    }
    
    private func saveScannedDocument(imageData: Data) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let documentName = "Scan \(timestamp)"
        let document = DocumentItem(name: documentName, imageData: imageData, parent: currentFolder)
        modelContext.insert(document)
        do {
            try modelContext.save()
        } catch {
            print("Failed to save document: \(error.localizedDescription)")
        }
    }
}

// MARK: - Document Preview View
struct DocumentPreviewView: View {
    let document: DocumentItem
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                if let image = UIImage(data: document.imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            }
            .navigationTitle(document.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
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
