import XCTest
@testable import Clerk

final class FileItemTests: XCTestCase {
    func testFileItemInitialization() {
        let file = FileItem(name: "test.pdf", parent: nil)
        XCTAssertEqual(file.name, "test.pdf")
        XCTAssertNil(file.parent)
    }
    
    func testFileItemWithParent() {
        let parent = FolderItem(name: "TestFolder", parent: nil)
        let file = FileItem(name: "test.pdf", parent: parent)
        XCTAssertEqual(file.name, "test.pdf")
        XCTAssertEqual(file.parent, parent)
    }
    
    func testFullURL() {
        let file = FileItem(name: "test.pdf", parent: nil)
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let expectedURL = documentsDirectory.appendingPathComponent("test.pdf")
        XCTAssertEqual(file.fullURL, expectedURL)
    }
    
    func testFullURLWithParent() {
        let parent = FolderItem(name: "TestFolder", parent: nil)
        let file = FileItem(name: "test.pdf", parent: parent)
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let expectedURL = documentsDirectory.appendingPathComponent("TestFolder/test.pdf")
        XCTAssertEqual(file.fullURL, expectedURL)
    }
    
    func testEnsureParentDirectoryExists() {
        let parent = FolderItem(name: "TestFolder", parent: nil)
        let file = FileItem(name: "test.pdf", parent: parent)
        
        // Ensure parent directory exists
        file.ensureParentDirectoryExists()
        
        // Verify parent directory exists
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let parentDirectory = documentsDirectory.appendingPathComponent("TestFolder")
        XCTAssertTrue(FileManager.default.fileExists(atPath: parentDirectory.path))
        
        // Clean up
        try? FileManager.default.removeItem(at: parentDirectory)
    }
} 