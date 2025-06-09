import SwiftUI
import PDFKit

struct DocumentReviewView: View {
    @ObservedObject var document: ScannedDocument
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let parent: FolderItem?
    
    @State private var editedSummary: String
    @State private var editedTitle: String
    @State private var isSaving = false
    
    init(document: ScannedDocument, parent: FolderItem?) {
        self.document = document
        self.parent = parent
        _editedSummary = State(initialValue: document.llmSummary)
        _editedTitle = State(initialValue: document.suggestedTitle)
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
        }
    }
    
    private func saveDocument() {
        isSaving = true
        
        // Update document with edited values
        document.llmSummary = editedSummary
        document.suggestedTitle = editedTitle
        
        // Generate PDF with the final title
        PDFGenerator.generatePDF(
            from: document.images,
            fileName: "\(editedTitle).pdf",
            parent: parent,
            modelContext: modelContext
        )
        
        isSaving = false
        dismiss()
    }
} 