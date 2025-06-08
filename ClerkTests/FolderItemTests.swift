import XCTest
@testable import Clerk

final class FolderItemTests: XCTestCase {
    func testFolderItemInitialization() {
        let folder = FolderItem(name: "TestFolder", parent: nil)
        XCTAssertEqual(folder.name, "TestFolder")
        XCTAssertNil(folder.parent)
    }
    
    func testFolderItemWithParent() {
        let parent = FolderItem(name: "ParentFolder", parent: nil)
        let child = FolderItem(name: "ChildFolder", parent: parent)
        XCTAssertEqual(child.name, "ChildFolder")
        XCTAssertEqual(child.parent, parent)
    }
    
    func testFolderHierarchy() {
        let root = FolderItem(name: "Root", parent: nil)
        let child = FolderItem(name: "Child", parent: root)
        let grandchild = FolderItem(name: "Grandchild", parent: child)
        
        XCTAssertNil(root.parent)
        XCTAssertEqual(child.parent, root)
        XCTAssertEqual(grandchild.parent, child)
    }
} 