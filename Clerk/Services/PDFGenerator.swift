import UIKit
import SwiftData
import PDFKit

struct PDFGenerator {
    static func generatePDF(from images: [UIImage], fileName: String, parent: FolderItem?, modelContext: ModelContext) {
        guard !images.isEmpty else { return }
        let pdfData = NSMutableData()
        let pdfConsumer = CGDataConsumer(data: pdfData as CFMutableData)!

        // Use first image size as the PDF page size, or default to standard if unavailable
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, nil) else { return }

        for image in images {
            let pageSize = CGRect(origin: .zero, size: image.size)
            var pageMediaBox = pageSize
            pdfContext.beginPage(mediaBox: &pageMediaBox)
            if let cgImage = image.cgImage {
                pdfContext.draw(cgImage, in: pageSize)
            }
            pdfContext.endPage()
        }
        pdfContext.closePDF()

        let newFile = FileItem(name: fileName, parent: parent)
        
        // Ensure the parent directory exists before saving
        newFile.ensureParentDirectoryExists()
        
        // Save the PDF file
        do {
            try pdfData.write(to: newFile.fullURL, options: .atomic)
            modelContext.insert(newFile)
            try modelContext.save()
            print("Successfully saved file '\(fileName)' to folder: \(parent?.name ?? "root")")
            print("File saved at path: \(newFile.fullURL.path)")
        } catch {
            print("Failed to save file: \(error.localizedDescription)")
        }
    }

    static func pdfToImages(url: URL) -> [UIImage]? {
        guard let pdfDocument = PDFDocument(url: url) else {
            print("Could not create PDFDocument from URL.")
            return nil
        }

        var images: [UIImage] = []
        for i in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: i) else { continue }
            let pageRect = page.bounds(for: .mediaBox)
            let renderer = UIGraphicsImageRenderer(size: pageRect.size)
            let image = renderer.image { ctx in
                UIColor.white.set()
                ctx.fill(pageRect)
                ctx.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
                ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            images.append(image)
        }
        return images
    }
}
