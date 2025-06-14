import Foundation
import os.log

@objc(CrashHandler)
public class CrashHandler: NSObject {
    static let shared = CrashHandler()
    private static let logger = Logger(subsystem: "com.clerkapp.Clerk", category: "CrashHandler")
    
    private override init() {
        super.init()
        setupExceptionHandler()
    }
    
    private func setupExceptionHandler() {
        NSSetUncaughtExceptionHandler { exception in
            CrashHandler.handleException(exception)
        }
    }
    
    private static func handleException(_ exception: NSException) {
        let stackTrace = exception.callStackSymbols.joined(separator: "\n")
        let reason = exception.reason ?? "Unknown reason"
        let name = exception.name.rawValue
        
        logger.error("""
            Share Extension crashed:
            Name: \(name)
            Reason: \(reason)
            Stack trace:
            \(stackTrace)
            """)
        
        // Try to write to a file in the shared container
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.clerkapp.Clerk") {
            let crashLogURL = containerURL.appendingPathComponent("share_extension_crash.log")
            let crashLog = """
                Crash Time: \(Date())
                Name: \(name)
                Reason: \(reason)
                Stack trace:
                \(stackTrace)
                """
            
            try? crashLog.write(to: crashLogURL, atomically: true, encoding: .utf8)
        }
    }
} 