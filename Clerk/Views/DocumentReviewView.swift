import SwiftUI
import PDFKit
import SwiftData

struct DocumentReviewView: View {
    @ObservedObject var document: ScannedDocument
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var folders: [FolderItem]
    let parent: FolderItem?
    
    @State private var editedSummary: String
    @State private var editedTitle: String
    @State private var isSaving = false
    @State private var selectedFolder: FolderItem?
    @State private var shouldCreateNewFolder: Bool
    @State private var newFolderName: String
    @State private var showingFolderAlert = false
    
    init(document: ScannedDocument, parent: FolderItem?) {
        self.document = document
        self.parent = parent
        _editedSummary = State(initialValue: document.llmSummary)
        _editedTitle = State(initialValue: document.suggestedTitle)
        _shouldCreateNewFolder = State(initialValue: document.shouldCreateNewFolder)
        _newFolderName = State(initialValue: document.newFolderName ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Document Preview") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(document.images, id: \.self) { image in
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 200)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section("Summary") {
                    TextEditor(text: $editedSummary)
                        .frame(minHeight: 100)
                }
                
                Section("Title") {
                    TextField("Document Title", text: $editedTitle)
                }
                
                Section("Storage Location") {
                    if shouldCreateNewFolder {
                        TextField("New Folder Name", text: $newFolderName)
                    } else {
                        Picker("Select Folder", selection: $selectedFolder) {
                            Text("None").tag(nil as FolderItem?)
                            ForEach(folders) { folder in
                                Text(folder.getPath().map { $0.name }.joined(separator: "/"))
                                    .tag(folder as FolderItem?)
                            }
                        }
                    }
                    
                    Toggle("Create New Folder", isOn: $shouldCreateNewFolder)
                }
                
                Section {
                    Button(action: saveDocument) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Save Document")
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .navigationTitle("Review Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Invalid Folder Name", isPresented: $showingFolderAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please enter a valid folder name")
            }
            .onAppear {
                // Set up folder selection after view appears and model context is available
                if let suggestedFolderPath = document.suggestedFolder {
                    let folderNames = suggestedFolderPath.split(separator: "/")
                    if let firstFolderName = folderNames.first {
                        // Find the root folder with this name
                        if let rootFolder = folders.first(where: { $0.name == String(firstFolderName) && $0.parent == nil }) {
                            var currentFolder = rootFolder
                            // Navigate through the path
                            for folderName in folderNames.dropFirst() {
                                if let nextFolder = currentFolder.subfolders.first(where: { $0.name == String(folderName) }) {
                                    currentFolder = nextFolder
                                } else {
                                    break
                                }
                            }
                            selectedFolder = currentFolder
                        }
                    }
                }
            }
        }
    }
    
    private func saveDocument() {
        isSaving = true
        
        // Update document with edited values
        document.llmSummary = editedSummary
        document.suggestedTitle = editedTitle
        
        // Handle folder creation or selection
        let targetFolder: FolderItem
        if shouldCreateNewFolder {
            guard !newFolderName.isEmpty else {
                showingFolderAlert = true
                isSaving = false
                return
            }
            targetFolder = FolderItem(name: newFolderName, parent: parent)
            modelContext.insert(targetFolder)
        } else {
            targetFolder = selectedFolder ?? parent ?? FolderItem(name: "Documents")
            if targetFolder.name == "Documents" {
                modelContext.insert(targetFolder)
            }
        }
        
        // Generate PDF with the final title
        PDFGenerator.generatePDF(
            from: document.images,
            fileName: "\(editedTitle).pdf",
            parent: targetFolder,
            modelContext: modelContext
        )
        
        isSaving = false
        dismiss()
    }
} 