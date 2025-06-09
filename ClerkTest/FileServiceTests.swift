import XCTest
import SwiftData
@testable import Clerk

final class FileServiceTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUp() {
        super.setUp()
        // Create an in-memory container for testing
        let schema = Schema([FileItem.self, FolderItem.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try! ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)
    }
    
    override func tearDown() {
        modelContainer = nil
        modelContext = nil
        super.tearDown()
    }
    
    func testDeleteFile() {
        // Create a test file
        let file = FileItem(name: "test.pdf", parent: nil)
        modelContext.insert(file)
        
        // Create the file in the filesystem
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent("test.pdf")
        
        // Create an empty PDF file
        let pdfData = Data()
        try? pdfData.write(to: fileURL)
        
        // Verify file exists
        XCTAssertTrue(fileManager.fileExists(atPath: fileURL.path))
        
        // Delete the file
        FileService.deleteFile(file, modelContext: modelContext)
        
        // Verify file is deleted from filesystem
        XCTAssertFalse(fileManager.fileExists(atPath: fileURL.path))
        
        // Verify file is deleted from SwiftData
        let fetchDescriptor = FetchDescriptor<FileItem>()
        let files = try? modelContext.fetch(fetchDescriptor)
        XCTAssertEqual(files?.count, 0)
    }
} 