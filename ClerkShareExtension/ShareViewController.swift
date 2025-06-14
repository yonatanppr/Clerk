import UIKit
import UniformTypeIdentifiers
import os.log

@objc(ShareViewController)
public class ShareViewController: UIViewController {
    
    private let logger = Logger(subsystem: "com.clerkapp.Clerk", category: "ShareExtension")
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        // Initialize crash handler as early as possible
        _ = CrashHandler.shared
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        // Initialize crash handler as early as possible
        _ = CrashHandler.shared
    }
    
    override public func loadView() {
        super.loadView()
        logger.info("Share Extension: LoadView")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        logger.info("Share Extension: ViewDidLoad")
        
        // Basic initialization check
        guard Bundle.main.bundleIdentifier != nil else {
            logger.error("Share Extension: Bundle identifier is nil")
            return
        }
        
        // Ensure we're on the main thread for UI operations
        DispatchQueue.main.async { [weak self] in
            self?.view.isHidden = true
            self?.handleSharedImage()
        }
    }
    
    private func handleSharedImage() {
        logger.info("Share Extension: Starting to handle shared image")
        
        guard let extensionContext = self.extensionContext else {
            logger.error("Share Extension: No extension context available")
            completeRequest()
            return
        }
        
        guard let extensionItem = extensionContext.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            logger.error("Share Extension: No input items or attachments found")
            completeRequest()
            return
        }

        let imageType = UTType.image.identifier
        if itemProvider.hasItemConformingToTypeIdentifier(imageType) {
            logger.info("Share Extension: Found image type item")
            
            itemProvider.loadDataRepresentation(forTypeIdentifier: imageType) { [weak self] (data, error) in
                if let error = error {
                    self?.logger.error("Share Extension: Error loading image data: \(error.localizedDescription)")
                    self?.completeRequest()
                    return
                }
                
                guard let data = data else {
                    self?.logger.error("Share Extension: No image data received")
                    self?.completeRequest()
                    return
                }
                
                self?.logger.info("Share Extension: Successfully loaded image data")
                self?.saveImageToSharedContainer(data: data)
            }
        } else {
            logger.error("Share Extension: Item provider does not conform to image type")
            completeRequest()
        }
    }

    private func saveImageToSharedContainer(data: Data) {
        logger.info("Share Extension: Attempting to save image to shared container")
        
        let appGroupIdentifier = "group.clerkapp.Clerk"
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            logger.error("Share Extension: Failed to get container URL for app group")
            completeRequest()
            return
        }

        let fileName = "sharedImage-\(UUID().uuidString).jpg"
        let fileURL = containerURL.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL)
            logger.info("Share Extension: Successfully saved image to \(fileURL.path)")
            openMainApp(with: fileName)
        } catch {
            logger.error("Share Extension: Failed to save image: \(error.localizedDescription)")
            completeRequest()
        }
    }

    private func openMainApp(with fileName: String) {
        let escapedFileName = fileName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "clerk://import?filename=\(escapedFileName)") else {
            logger.error("Share Extension: Failed to create URL for main app")
            completeRequest()
            return
        }
        
        logger.info("Share Extension: Opening main app with URL: \(url.absoluteString)")
        
        // Try to open the main app using the extension context
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:]) { [weak self] success in
                    if !success {
                        self?.logger.error("Share Extension: Failed to open main app")
                    } else {
                        self?.logger.info("Share Extension: Successfully opened main app")
                    }
                    self?.completeRequest()
                }
                return
            }
            responder = responder?.next
        }
        
        // Fallback to extension context if UIApplication is not available
        self.extensionContext?.open(url, completionHandler: { [weak self] success in
            if !success {
                self?.logger.error("Share Extension: Failed to open main app")
            } else {
                self?.logger.info("Share Extension: Successfully opened main app")
            }
            self?.completeRequest()
        })
    }

    private func completeRequest() {
        logger.info("Share Extension: Completing request")
        DispatchQueue.main.async { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
}
