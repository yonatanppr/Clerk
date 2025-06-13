import UIKit
import UniformTypeIdentifiers

@objc(ShareViewController)
public class ShareViewController: UIViewController {

    override public func viewDidLoad() {
        super.viewDidLoad()
        self.view.isHidden = true // The extension has no UI, it works in the background
        handleSharedImage()
    }
    
    private func handleSharedImage() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            completeRequest()
            return
        }

        let imageType = UTType.image.identifier
        if itemProvider.hasItemConformingToTypeIdentifier(imageType) {
            itemProvider.loadDataRepresentation(forTypeIdentifier: imageType) { [weak self] (data, error) in
                if let data = data {
                    self?.saveImageToSharedContainer(data: data)
                } else {
                    self?.completeRequest()
                }
            }
        } else {
            completeRequest()
        }
    }

    private func saveImageToSharedContainer(data: Data) {
        // Use your correct App Group ID
        let appGroupIdentifier = "group.com.clerkapp.Clerk"
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            completeRequest()
            return
        }

        let fileName = "sharedImage-\(UUID().uuidString).jpg"
        let fileURL = containerURL.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL)
            openMainApp(with: fileName)
        } catch {
            completeRequest()
        }
    }

    private func openMainApp(with fileName: String) {
        let escapedFileName = fileName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "clerk://import?filename=\(escapedFileName)") else {
            completeRequest()
            return
        }
        
        self.extensionContext?.open(url, completionHandler: { success in
            self.completeRequest()
        })
    }

    private func completeRequest() {
        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
}
