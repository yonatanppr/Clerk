import SwiftUI
import PDFKit
import SwiftData
import EventKit

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
    @State private var showingCalendarAlert = false
    @State private var calendarEventTitle = ""
    @State private var calendarEventDate = Date()
    @State private var showingCalendarAccessDenied = false
    @State private var showingCalendarPermissionRequest = false
    @State private var showingDiscardAlert = false
    
    private let eventStore = EKEventStore()
    
    init(document: ScannedDocument, parent: FolderItem?) {
        self.document = document
        self.parent = parent
        _editedSummary = State(initialValue: document.llmSummary)
        _editedTitle = State(initialValue: document.suggestedTitle)
        _shouldCreateNewFolder = State(initialValue: document.shouldCreateNewFolder)
        _newFolderName = State(initialValue: document.newFolderName ?? "")
        
        // Initialize calendar event title if there's a required action
        if let action = document.requiredAction {
            _calendarEventTitle = State(initialValue: action.description)
            _calendarEventDate = State(initialValue: action.dueDate ?? Date())
        } else {
            _calendarEventTitle = State(initialValue: "")
            _calendarEventDate = State(initialValue: Date())
        }
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
                
                Section("Document Type") {
                    Text(document.documentType.rawValue.capitalized)
                        .foregroundColor(documentTypeColor)
                }
                
                if let action = document.requiredAction {
                    Section("Required Action") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Type: \(action.actionType.rawValue.capitalized)")
                            Text("Description: \(action.description)")
                            if let dueDate = action.dueDate {
                                Text("Due Date: \(dueDate.formatted(date: .long, time: .omitted))")
                            }
                            Text("Priority: \(action.priority.rawValue.capitalized)")
                                .foregroundColor(priorityColor(action.priority))
                        }
                        
                        Button("Add to Calendar") {
                            checkCalendarAccess()
                        }
                    }
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
                    
                    Button(role: .destructive) {
                        showingDiscardAlert = true
                    } label: {
                        Text("Discard Document")
                    }
                    .disabled(isSaving)
                }
            }
            .navigationTitle("Review Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingDiscardAlert = true
                    }
                }
            }
            .alert("Invalid Folder Name", isPresented: $showingFolderAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please enter a valid folder name")
            }
            .alert("Calendar Access Denied", isPresented: $showingCalendarAccessDenied) {
                Button("Open Settings", role: .none) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable calendar access in Settings to add events.")
            }
            .alert("Calendar Access Required", isPresented: $showingCalendarPermissionRequest) {
                Button("Allow Access", role: .none) {
                    requestCalendarAccess()
                }
                Button("Not Now", role: .cancel) { }
            } message: {
                Text("Clerk needs access to your calendar to add events for required actions. Would you like to grant access now?")
            }
            .alert("Discard Document", isPresented: $showingDiscardAlert) {
                Button("Discard", role: .destructive) {
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to discard this document? This action cannot be undone.")
            }
            .sheet(isPresented: $showingCalendarAlert) {
                NavigationView {
                    Form {
                        Section("Calendar Event") {
                            TextField("Event Title", text: $calendarEventTitle)
                            DatePicker("Date", selection: $calendarEventDate, displayedComponents: [.date])
                        }
                    }
                    .navigationTitle("Add to Calendar")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                showingCalendarAlert = false
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Add") {
                                addToCalendar()
                                showingCalendarAlert = false
                            }
                        }
                    }
                }
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
    
    private var documentTypeColor: Color {
        switch document.documentType {
        case .spam:
            return .gray
        case .informational:
            return .blue
        case .actionRequired:
            return .red
        case .unknown:
            return .gray
        }
    }
    
    private func priorityColor(_ priority: ScannedDocument.RequiredAction.Priority) -> Color {
        switch priority {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .green
        }
    }
    
    private func checkCalendarAccess() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            showingCalendarPermissionRequest = true
        case .restricted, .denied:
            showingCalendarAccessDenied = true
        case .authorized:
            showingCalendarAlert = true
        @unknown default:
            showingCalendarAccessDenied = true
        }
    }
    
    private func requestCalendarAccess() {
        eventStore.requestAccess(to: .event) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    showingCalendarAlert = true
                } else {
                    showingCalendarAccessDenied = true
                }
            }
        }
    }
    
    private func addToCalendar() {
        let event = EKEvent(eventStore: eventStore)
        event.title = calendarEventTitle
        event.startDate = calendarEventDate
        event.endDate = calendarEventDate.addingTimeInterval(3600) // 1 hour duration
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            print("Error saving event: \(error.localizedDescription)")
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