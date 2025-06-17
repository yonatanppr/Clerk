import PDFKit
import SwiftUI
import SwiftData
import DocumentScannerView
import QuickLook
import UniformTypeIdentifiers
import PhotosUI
import Vision


class DragState: ObservableObject {
    @Published var isDraggingOver = false
}

struct FileSystemView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var folders: [FolderItem]
    @Query private var files: [FileItem]
    @StateObject private var dragState = DragState()
    
    let currentFolder: FolderItem?
    @Binding var navigationPath: NavigationPath // For programmatic navigation
    
    // Add computed property to track empty state
    private var isEmpty: Bool {
        files.isEmpty
    }
    
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

    // Import state
    @State private var isShowingImagePicker = false
    @State private var isShowingDocumentPicker = false

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
    
    private var addFolderRow: some View {
        Button {
            newFolderName = ""
            showingCreateFolderAlert = true
        } label: {
            HStack {
                Image(systemName: "folder.badge.plus")
                Text("Add Folder")
            }
            .foregroundColor(.blue)
        }
    }

    var body: some View {
        let folderSection: some View = Group {
            if !folders.isEmpty {
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
                    addFolderRow
                }
            }
        }

        return VStack(spacing: 0) { // Use a VStack to arrange BreadcrumbView and the List
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
                VStack(spacing: 0) {
                    List {
                        if !folders.isEmpty {
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
                                // Add Folder button row
                                addFolderRow
                            }
                        }
                        
                        if isEmpty {
                            Section {
                                DropView(currentFolder: currentFolder)
                                    .listRowInsets(EdgeInsets())
                                    .listRowBackground(Color.clear)
                            }
                        }
                        
                        if !files.isEmpty {
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
                                    .environmentObject(dragState)
                                    .listRowBackground(dragState.isDraggingOver ? Color.gray.opacity(0.1) : Color.clear)
                                }
                            }
                        }
                    }
                    .background(Color.clear)
                    
                    HStack {
                        Spacer()
                        
                        Menu {
                            Button(action: { isShowingImagePicker = true }) {
                                Label("Photo Library", systemImage: "photo.on.rectangle")
                            }
                            Button(action: { isShowingDocumentPicker = true }) {
                                Label("From Files", systemImage: "folder")
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 28, weight: .medium))
                                .frame(width: 60, height: 60)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(color: .gray.opacity(0.6), radius: 8, x: 0, y: 4)
                        }
                        .accessibilityLabel("Import document")

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
        .onReceive(NotificationCenter.default.publisher(for: .didReceiveFile)) { notification in
            if let fileURL = notification.object as? URL {
                if let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) {
                    processImages([image])
                    try? FileManager.default.removeItem(at: fileURL)
                }
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
                    analyzeAndPresentReview(images: scannedImages)
                case .failure(let error):
                    print("Scan failed: \(error.localizedDescription)")
                }
            }
        }
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(onImagesPicked: { images in
                processImages(images)
            })
        }
        .sheet(isPresented: $isShowingDocumentPicker) {
            DocumentPicker(onDocumentsPicked: { urls in
                processURLs(urls)
            })
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

    private func processImages(_ images: [UIImage]) {
        guard !images.isEmpty else { return }
        analyzeAndPresentReview(images: images)
    }

    private func processURLs(_ urls: [URL]) {
        for url in urls {
            let secured = url.startAccessingSecurityScopedResource()
            defer {
                if secured {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let resourceValues = try url.resourceValues(forKeys: [.contentTypeKey])
                if let type = resourceValues.contentType {
                    if type.conforms(to: .pdf) {
                        if let images = PDFGenerator.pdfToImages(url: url) {
                            analyzeAndPresentReview(images: images)
                        }
                    } else if type.conforms(to: .image) {
                        if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                            processImages([image])
                        }
                    }
                }
            } catch {
                print("Failed to get resource values for url: \(url), error: \(error)")
            }
        }
    }
    
    private func analyzeAndPresentReview(images: [UIImage]) {
        Task {
            isProcessingDocument = true
            let document = ScannedDocument(images: images)
            currentDocument = document

            do {
                let recognizedText = try OCRService.recognizeText(from: images)
                let allFolders = (try? modelContext.fetch(FetchDescriptor<FolderItem>())) ?? []
                let (summary, title, folderSuggestion, documentType, requiredAction) = try await LLMService.analyzeDocument(
                    text: recognizedText,
                    existingFolders: allFolders
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
    }
}


struct ImagePicker: UIViewControllerRepresentable {
    var onImagesPicked: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            var selectedImages: [UIImage] = []
            let group = DispatchGroup()

            for result in results {
                group.enter()
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    result.itemProvider.loadObject(ofClass: UIImage.self) { (image, error) in
                        if let image = image as? UIImage {
                            selectedImages.append(image)
                        }
                        group.leave()
                    }
                } else {
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                self.parent.onImagesPicked(selectedImages)
            }
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    var onDocumentsPicked: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [UTType.pdf, UTType.image]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onDocumentsPicked(urls)
        }
    }
}
