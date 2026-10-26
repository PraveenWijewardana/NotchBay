import Foundation
import AppKit
import Combine
import UniformTypeIdentifiers

@MainActor
public final class DropShelfService: ObservableObject {
    @Published public var items: [ShelfItem] = []
    @Published public var selectedFilter: ShelfItemType = .all
    @Published public var isTargeted: Bool = false
    @Published public var copiedItemId: UUID? = nil
    @Published public var hoveredItemId: UUID? = nil
    @Published public var toastMessage: String? = nil
    @Published public var activeSubTab: Int = 0 // 0: Drop Shelf, 1: Clipboard History
    
    public var filteredItems: [ShelfItem] {
        if selectedFilter == .all {
            return items
        }
        return items.filter { $0.itemType == selectedFilter }
    }
    
    private var toastTask: Task<Void, Never>?
    
    public init() {
        // Starts clean and empty
    }
    
    // MARK: - Paste from Clipboard
    @discardableResult
    public func pasteFromClipboard() -> Bool {
        let pasteboard = NSPasteboard.general
        var addedCount = 0
        
        // 1. Check for file URLs first
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            for url in urls {
                addFile(url: url)
                addedCount += 1
            }
        }
        // 2. Check for image data (screenshots, copied image from browser/Photoshop)
        else if let image = NSImage(pasteboard: pasteboard),
                let tiffData = image.tiffRepresentation,
                let bitmap = NSBitmapImageRep(data: tiffData),
                let pngData = bitmap.representation(using: .png, properties: [:]) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH.mm.ss"
            let timeString = formatter.string(from: Date())
            let name = "Pasted Image \(timeString).png"
            addImage(data: pngData, name: name)
            addedCount += 1
        }
        // 3. Check for plain text or links
        else if let text = pasteboard.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            addText(text)
            addedCount += 1
        }
        
        if addedCount > 0 {
            showToast("Pasted \(addedCount) item\(addedCount > 1 ? "s" : "") from clipboard!")
            return true
        } else {
            showToast("Clipboard is empty or unsupported")
            return false
        }
    }
    
    // MARK: - Copy Item to Clipboard
    public func copyItemToClipboard(id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        if let hex = item.colorHex {
            pasteboard.setString(hex, forType: .string)
            showToast("Copied \(hex) to clipboard!")
        } else if let path = item.path {
            // Write file URL so Finder, Slack, Mail, etc. treat it as a real file
            pasteboard.writeObjects([path as NSURL])
            showToast("Copied file to clipboard!")
        } else if let imgData = item.imageData, item.itemType == .image, let img = NSImage(data: imgData) {
            pasteboard.writeObjects([img])
            showToast("Copied image to clipboard!")
        } else if let text = item.stringContent {
            pasteboard.setString(text, forType: .string)
            showToast("Copied to clipboard!")
        }
        
        copiedItemId = id
        toastTask?.cancel()
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if self?.copiedItemId == id {
                self?.copiedItemId = nil
                self?.toastMessage = nil
            }
        }
    }
    
    // MARK: - Copy All Items to Clipboard
    public func copyAllToClipboard() {
        guard !items.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        let fileURLs = items.compactMap { $0.path as NSURL? }
        if fileURLs.count == items.count {
            // All items are files: write all file URLs
            pasteboard.writeObjects(fileURLs)
            showToast("Copied all \(fileURLs.count) files!")
        } else {
            // Mixed or text items: combine into formatted string
            var combinedStrings: [String] = []
            for item in items {
                if let hex = item.colorHex {
                    combinedStrings.append(hex)
                } else if let path = item.path {
                    combinedStrings.append(path.path)
                } else if let text = item.stringContent {
                    combinedStrings.append(text)
                } else {
                    combinedStrings.append(item.name)
                }
            }
            pasteboard.setString(combinedStrings.joined(separator: "\n\n"), forType: .string)
            showToast("Copied all \(items.count) items!")
        }
    }
    
    // MARK: - Add Handlers
    public func addFile(url: URL) {
        let name = url.lastPathComponent
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let formattedSize = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        
        let ext = url.pathExtension.lowercased()
        let isImage = ["png", "jpg", "jpeg", "gif", "webp", "heic", "svg", "tiff", "bmp"].contains(ext)
        
        var imgData: Data? = nil
        if isImage, let fullImg = NSImage(contentsOf: url) {
            let maxDim: CGFloat = 200
            let scale = min(maxDim / max(1, fullImg.size.width), maxDim / max(1, fullImg.size.height), 1.0)
            let thumbSize = NSSize(width: fullImg.size.width * scale, height: fullImg.size.height * scale)
            let thumb = NSImage(size: thumbSize)
            thumb.lockFocus()
            fullImg.draw(in: NSRect(origin: .zero, size: thumbSize), from: NSRect(origin: .zero, size: fullImg.size), operation: .copy, fraction: 1.0)
            thumb.unlockFocus()
            imgData = (thumb.tiffRepresentation.flatMap { NSBitmapImageRep(data: $0) })?.representation(using: .jpeg, properties: [.compressionFactor: 0.75])
        } else {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 96, height: 96)
            imgData = (icon.tiffRepresentation.flatMap { NSBitmapImageRep(data: $0) })?.representation(using: .png, properties: [:])
        }
        
        let item = ShelfItem(
            name: name,
            path: url,
            stringContent: nil,
            imageData: imgData,
            colorHex: nil,
            fileSizeFormatted: formattedSize,
            itemType: isImage ? .image : .file
        )
        items.insert(item, at: 0)
    }
    
    public func addImage(data: Data, name: String) {
        let sizeFormatted = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
        var previewData = data
        if let img = NSImage(data: data), (img.size.width > 220 || img.size.height > 220) {
            let maxDim: CGFloat = 200
            let scale = min(maxDim / max(1, img.size.width), maxDim / max(1, img.size.height), 1.0)
            let thumbSize = NSSize(width: img.size.width * scale, height: img.size.height * scale)
            let thumb = NSImage(size: thumbSize)
            thumb.lockFocus()
            img.draw(in: NSRect(origin: .zero, size: thumbSize), from: NSRect(origin: .zero, size: img.size), operation: .copy, fraction: 1.0)
            thumb.unlockFocus()
            if let compressed = (thumb.tiffRepresentation.flatMap { NSBitmapImageRep(data: $0) })?.representation(using: .jpeg, properties: [.compressionFactor: 0.75]) {
                previewData = compressed
            }
        }
        let item = ShelfItem(
            name: name,
            path: nil,
            stringContent: nil,
            imageData: previewData,
            colorHex: nil,
            fileSizeFormatted: sizeFormatted,
            itemType: .image
        )
        items.insert(item, at: 0)
    }
    
    public func addText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // 1. Check for Hex Color (#FFFFFF, #0000C7, etc.)
        let hexCheck = parseHexColor(trimmed)
        if hexCheck.isHex {
            let item = ShelfItem(
                name: hexCheck.formatted,
                path: nil,
                stringContent: hexCheck.formatted,
                imageData: nil,
                colorHex: hexCheck.formatted,
                fileSizeFormatted: "Hex Color",
                itemType: .color
            )
            items.insert(item, at: 0)
            return
        }
        
        // 2. Check for Link
        let isLink = trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") || trimmed.hasPrefix("www.")
        if isLink {
            let urlString = trimmed.hasPrefix("www.") ? "https://" + trimmed : trimmed
            var displayDomain = trimmed
            if let url = URL(string: urlString), let host = url.host {
                displayDomain = host
            }
            let item = ShelfItem(
                name: displayDomain,
                path: nil,
                stringContent: urlString,
                imageData: nil,
                colorHex: nil,
                fileSizeFormatted: "Link",
                itemType: .link
            )
            items.insert(item, at: 0)
            return
        }
        
        // 3. Check for Code Snippet
        if isCodeSnippet(trimmed) {
            let lines = trimmed.components(separatedBy: .newlines)
            let firstLine = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? trimmed
            let name = firstLine.count > 30 ? String(firstLine.prefix(30)) + "…" : firstLine
            let item = ShelfItem(
                name: name,
                path: nil,
                stringContent: trimmed,
                imageData: nil,
                colorHex: nil,
                fileSizeFormatted: "\(lines.count) lines",
                itemType: .code
            )
            items.insert(item, at: 0)
            return
        }
        
        // 4. Plain Text
        let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
        let name = firstLine.count > 28 ? String(firstLine.prefix(28)) + "…" : firstLine
        let item = ShelfItem(
            name: name,
            path: nil,
            stringContent: trimmed,
            imageData: nil,
            colorHex: nil,
            fileSizeFormatted: "\(trimmed.count) chars",
            itemType: .text
        )
        items.insert(item, at: 0)
    }
    
    // MARK: - Text Classification Helpers
    private func parseHexColor(_ str: String) -> (isHex: Bool, formatted: String) {
        var clean = str.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("#") {
            clean.removeFirst()
        }
        guard [3, 6, 8].contains(clean.count) else { return (false, "") }
        let validHex = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        guard CharacterSet(charactersIn: clean).isSubset(of: validHex) else { return (false, "") }
        return (true, "#" + clean.uppercased())
    }
    
    private func isCodeSnippet(_ str: String) -> Bool {
        let codeIndicators = [
            "func ", "def ", "class ", "import ", "const ", "let ", "var ",
            "return ", "public ", "private ", "struct ", "enum ", "protocol ",
            "=>", "function(", "console.log", "printf", "println", "void ",
            "int ", "float ", "double ", "package ", "namespace ", "</", "/>",
            "swift", "json", "python", "javascript"
        ]
        let lower = str.lowercased()
        for ind in codeIndicators {
            if lower.contains(ind) {
                return true
            }
        }
        if str.contains("\n") && (str.contains("{") || str.contains("}") || str.contains(";")) {
            return true
        }
        return false
    }
    
    public func openItem(id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        if let path = item.path {
            NSWorkspace.shared.open(path)
        } else if item.itemType == .link, let stringContent = item.stringContent, let url = URL(string: stringContent) {
            NSWorkspace.shared.open(url)
        }
    }
    
    public func revealInFinder(id: UUID) {
        guard let item = items.first(where: { $0.id == id }), let path = item.path else { return }
        NSWorkspace.shared.activateFileViewerSelecting([path])
    }
    
    public func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
    }
    
    public func clearAll() {
        items.removeAll()
        showToast("Shelf cleared")
    }
    
    // MARK: - AirDrop Sharing Methods
    public func airDropItem(id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        let shareItems = prepareShareItems(for: item)
        guard !shareItems.isEmpty else {
            showToast("Item cannot be shared")
            return
        }
        performAirDrop(with: shareItems, description: item.name)
    }
    
    public func airDropAll() {
        guard !items.isEmpty else { return }
        var allShareItems: [Any] = []
        for item in items {
            allShareItems.append(contentsOf: prepareShareItems(for: item))
        }
        guard !allShareItems.isEmpty else { return }
        performAirDrop(with: allShareItems, description: "\(allShareItems.count) items")
    }
    
    public func airDropClipboard() {
        let pasteboard = NSPasteboard.general
        var shareItems: [Any] = []
        
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            shareItems.append(contentsOf: urls)
        } else if let image = NSImage(pasteboard: pasteboard),
                  let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) {
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Clipboard_Image_\(Int(Date().timeIntervalSince1970)).png")
            try? pngData.write(to: tempURL)
            shareItems.append(tempURL)
        } else if let text = pasteboard.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            shareItems.append(text as NSString)
        }
        
        guard !shareItems.isEmpty else {
            showToast("Clipboard is empty")
            return
        }
        
        performAirDrop(with: shareItems, description: "Clipboard")
    }
    
    private func prepareShareItems(for item: ShelfItem) -> [Any] {
        if let path = item.path {
            return [path]
        } else if let imgData = item.imageData {
            let filename = item.name.isEmpty ? "Image_\(Int(Date().timeIntervalSince1970)).png" : item.name
            let safeFilename = filename.hasSuffix(".png") || filename.hasSuffix(".jpg") || filename.hasSuffix(".jpeg") ? filename : "\(filename).png"
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(safeFilename)
            if (try? imgData.write(to: tempURL)) != nil {
                return [tempURL]
            } else if let img = NSImage(data: imgData) {
                return [img]
            }
        } else if item.itemType == .link, let stringContent = item.stringContent, let url = URL(string: stringContent) {
            return [url]
        } else if let hex = item.colorHex {
            return [hex as NSString]
        } else if let text = item.stringContent {
            return [text as NSString]
        }
        return []
    }
    
    private func performAirDrop(with shareItems: [Any], description: String) {
        if let airDropService = NSSharingService(named: .sendViaAirDrop), airDropService.canPerform(withItems: shareItems) {
            airDropService.perform(withItems: shareItems)
            showToast("Opening AirDrop...")
        } else {
            let picker = NSSharingServicePicker(items: shareItems)
            if let window = NSApplication.shared.windows.first(where: { $0.isVisible }), let contentView = window.contentView {
                picker.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)
            } else {
                showToast("AirDrop unavailable")
            }
        }
    }
    
    private func showToast(_ msg: String) {
        toastMessage = msg
        toastTask?.cancel()
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            self?.toastMessage = nil
        }
    }
}
