import SwiftUI
import UniformTypeIdentifiers

/// A plain text file for ShareLink. Shares as a .txt file named after the
/// entry, or as plain text for apps that only accept text.
struct TextFileExport: Transferable {
    let fileName: String
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .plainText) { item in
            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent("ATGuideShare", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent(item.fileName)
            try Data(item.text.utf8).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
        ProxyRepresentation(exporting: { (item: TextFileExport) in item.text })
    }
}
