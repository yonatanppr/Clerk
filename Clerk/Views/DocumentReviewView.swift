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
    @State private var selectedImageIndex = 0
    @State private var isScrolling = false
    
    private let eventStore = EKEventStore()
    
    init(document: ScannedDocument, parent: FolderItem?) {
        self.document = document
        self.parent = parent
        _editedSummary = State(initialValue: document.llmSummary)
        _editedTitle = State(initialValue: document.suggestedTitle)
        _shouldCreateNewFolder = State(initialValue: document.shouldCreateNewFolder)
        _newFolderName = State(initialValue: document.newFolderName ?? "")
        
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
            ScrollView {
                VStack(spacing: 24) {
                    // Document Preview Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Document Preview")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        TabView(selection: $selectedImageIndex) {
                            ForEach(Array(document.images.enumerated()), id: \.offset) { index, image in
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 300)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(radius: 8)
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(.page)
                        .frame(height: 300)
                        .onChange(of: selectedImageIndex) { _, _ in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isScrolling = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isScrolling = false
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Summary Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Summary")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $editedSummary)
                            .frame(minHeight: 120)
                            .padding(12)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal)
                    
                    // Title Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Title")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        TextField("Document Title", text: $editedTitle)
                            .padding(12)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal)
                    
                    // Document Type Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Document Type")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text(document.documentType.rawValue.capitalized)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(documentTypeColor)
                                .clipShape(Capsule())
                            
                            Spacer()
                        }
                    }
                    .padding(.horizontal)
                    
                    if let action = document.requiredAction {
                        // Required Action Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Required Action")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.red)
                                    Text(action.actionType.rawValue.capitalized)
                                        .font(.subheadline)
                                        .foregroundColor(.red)
                                }
                                
                                Text(action.description)
                                    .font(.body)
                                
                                if let dueDate = action.dueDate {
                                    HStack {
                                        Image(systemName: "calendar")
                                            .foregroundColor(.blue)
                                        Text(dueDate.formatted(date: .long, time: .omitted))
                                            .font(.subheadline)
                                    }
                                }
                                
                                HStack {
                                    Image(systemName: "flag.fill")
                                        .foregroundColor(priorityColor(action.priority))
                                    Text(action.priority.rawValue.capitalized)
                                        .font(.subheadline)
                                        .foregroundColor(priorityColor(action.priority))
                                }
                                
                                Button(action: { checkCalendarAccess() }) {
                                    HStack {
                                        Image(systemName: "calendar.badge.plus")
                                        Text("Add to Calendar")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(.horizontal)
                    }
                    
                    // Storage Location Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Storage Location")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 16) {
                            if shouldCreateNewFolder {
                                TextField("New Folder Name", text: $newFolderName)
                                    .textFieldStyle(.roundedBorder)
                                    .padding(.horizontal, 4)
                            } else {
                                Menu {
                                    Button("None") {
                                        selectedFolder = nil
                                    }
                                    
                                    ForEach(folders) { folder in
                                        Button(folder.getPath().map { $0.name }.joined(separator: "/")) {
                                            selectedFolder = folder
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(selectedFolder?.getPath().map { $0.name }.joined(separator: "/") ?? "Select Folder")
                                            .foregroundColor(selectedFolder == nil ? .secondary : .primary)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            
                            Toggle("Create New Folder", isOn: $shouldCreateNewFolder)
                                .tint(.blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Action Buttons
                    VStack(spacing: 16) {
                        Button(action: saveDocument) {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("Save Document")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isSaving ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isSaving)
                        
                        Button(role: .destructive) {
                            showingDiscardAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Discard Document")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isSaving)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .padding(.vertical)
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
                if let suggestedFolderPath = document.suggestedFolder {
                    let targetPath = suggestedFolderPath.split(separator: "/").map(String.init)
                    
                    let allFolders = folders
                    
                    let targetFolder = allFolders.first { folder in
                        let folderPath = folder.getPath().map { $0.name }
                        return folderPath == targetPath
                    }
                    
                    if let targetFolder {
                        self.selectedFolder = targetFolder
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
