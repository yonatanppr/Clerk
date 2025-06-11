import XCTest
import SwiftUI
import SwiftData
@testable import Clerk

final class DocumentReviewViewTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var testDocument: ScannedDocument!
    
    override func setUp() {
        super.setUp()
        // Create an in-memory container for testing
        let schema = Schema([FolderItem.self, FileItem.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try! ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)
        
        // Create a test document with a sample image
        let testImage = UIImage(systemName: "doc.text")!
        testDocument = ScannedDocument(images: [testImage])
        testDocument.llmSummary = "Test summary"
        testDocument.suggestedTitle = "Test Document"
        testDocument.documentType = .informational
    }
    
    override func tearDown() {
        modelContainer = nil
        modelContext = nil
        testDocument = nil
        super.tearDown()
    }
    
    func testDiscardDocument() {
        // Create a test folder
        let testFolder = FolderItem(name: "Test Folder")
        modelContext.insert(testFolder)
        
        // Create a test view
        let view = DocumentReviewView(document: testDocument, parent: testFolder)
            .modelContext(modelContext)
        
        // Create a UIHostingController to host the view
        let hostingController = UIHostingController(rootView: view)
        
        // Trigger the discard action
        let discardButton = hostingController.view.findButton(withTitle: "Discard Document")
        XCTAssertNotNil(discardButton, "Discard button should exist")
        
        // Simulate button tap
        discardButton?.sendActions(for: .touchUpInside)
        
        // Verify the alert is shown
        let alert = hostingController.view.findAlert(withTitle: "Discard Document")
        XCTAssertNotNil(alert, "Discard confirmation alert should be shown")
        
        // Find the "Discard" action in the alert
        let discardAction = alert?.actions.first { $0.title == "Discard" }
        XCTAssertNotNil(discardAction, "Discard action should exist in alert")
        
        // Dismiss the alert by simulating the discard action
        alert?.dismiss(animated: false) {
            // Verify no files were created in the test folder
            let fetchDescriptor = FetchDescriptor<FileItem>()
            let files = try? self.modelContext.fetch(fetchDescriptor)
            XCTAssertEqual(files?.count, 0, "No files should be created when document is discarded")
        }
    }
}

// MARK: - View Finding Helpers
private extension UIView {
    func findButton(withTitle title: String) -> UIButton? {
        if let button = self as? UIButton, button.title(for: .normal) == title {
            return button
        }
        
        for subview in subviews {
            if let button = subview.findButton(withTitle: title) {
                return button
            }
        }
        
        return nil
    }
    
    func findAlert(withTitle title: String) -> UIAlertController? {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            for window in windowScene.windows {
                if let alertController = window.rootViewController?.presentedViewController as? UIAlertController,
                   alertController.title == title {
                    return alertController
                }
            }
        }
        return nil
    }
} 