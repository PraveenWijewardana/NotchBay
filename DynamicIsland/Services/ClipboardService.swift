import Foundation
import AppKit
import Combine

public enum ClipboardItemType: String, Codable, Sendable, CaseIterable {
    case text = "Text"
    case code = "Code"
    case url = "Link"
    case color = "Color"
    case image = "Image"
    
    public var iconName: String {
        switch self {
        case .text: return "doc.text.fill"
        case .code: return "curlybraces"
        case .url: return "link"
        case .color: return "paintpalette.fill"
        case .image: return "photo.fill"
        }
    }
}

public struct ClipboardItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let textContent: String
    public let type: ClipboardItemType
    public let date: Date
    public let imageData: Data?
    public let preview: String
    
    public init(
        id: UUID = UUID(),
        textContent: String,
        type: ClipboardItemType,
        date: Date = Date(),
        imageData: Data? = nil,
        preview: String
    ) {
        self.id = id
        self.textContent = textContent
        self.type = type
        self.date = date
        self.imageData = imageData
        self.preview = preview
    }
    
    public var timeAgoFormatted: String {
        let seconds = max(1, Int(Date().timeIntervalSince(date)))
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3600)h ago"
    }
}

@MainActor
public final class ClipboardService: ObservableObject {
    @Published public var items: [ClipboardItem] = []
    @Published public var selectedFilter: ClipboardItemType? = nil
    
    private var lastChangeCount: Int = 0
    private var pollTimer: Timer?
    private let maxHistoryCount = 25
    
    public init() {
        self.lastChangeCount = NSPasteboard.general.changeCount
        // Populate initial clipboard item if present
        checkPasteboard()
        startMonitoring()
    }
    
    deinit {
        pollTimer?.invalidate()
    }
    
    public func startMonitoring() {
        pollTimer?.invalidate()
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkPasteboard()
            }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }
    
    public func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount
        
        // 1. Check for Image
        if let image = NSImage(pasteboard: pasteboard) {
            let maxDimension: CGFloat = 200
            let originalWidth = max(1, image.size.width)
            let originalHeight = max(1, image.size.height)
            let scale = min(maxDimension / originalWidth, maxDimension / originalHeight, 1.0)
            let thumbSize = NSSize(width: originalWidth * scale, height: originalHeight * scale)
            
            let thumbImg = NSImage(size: thumbSize)
            thumbImg.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: thumbSize), from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1.0)
            thumbImg.unlockFocus()
            
            let thumbData = (thumbImg.tiffRepresentation.flatMap { NSBitmapImageRep(data: $0) })?.representation(using: .jpeg, properties: [.compressionFactor: 0.75])
            
            let item = ClipboardItem(
                textContent: "Image (\(Int(originalWidth)) × \(Int(originalHeight)))",
                type: .image,
                imageData: thumbData,
                preview: "Copied Image (\(Int(originalWidth)) × \(Int(originalHeight)))"
            )
            addItem(item)
            return
        }
        
        // 2. Check for Plain Text / String
        if let string = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty {
            // Detect type: URL, Color hex, Code snippet, or plain Text
            let type: ClipboardItemType
            if string.hasPrefix("http://") || string.hasPrefix("https://") || string.hasPrefix("www.") {
                type = .url
            } else if (string.hasPrefix("#") && (string.count == 7 || string.count == 4)) || (string.hasPrefix("rgb(") || string.hasPrefix("rgba(")) {
                type = .color
            } else if isLikelyCode(string) {
                type = .code
            } else {
                type = .text
            }
            
            let preview = string.components(separatedBy: .newlines)
                .first?
                .trimmingCharacters(in: .whitespaces) ?? string
            let trimmedPreview = preview.count > 60 ? String(preview.prefix(57)) + "..." : preview
            
            let item = ClipboardItem(
                textContent: string,
                type: type,
                imageData: nil,
                preview: trimmedPreview
            )
            addItem(item)
        }
    }
    
    private func addItem(_ item: ClipboardItem) {
        // Avoid consecutive duplicate
        if let first = items.first, first.textContent == item.textContent {
            return
        }
        // Remove prior instance of same text
        items.removeAll { $0.textContent == item.textContent }
        items.insert(item, at: 0)
        if items.count > maxHistoryCount {
            items = Array(items.prefix(maxHistoryCount))
        }
    }
    
    private func isLikelyCode(_ text: String) -> Bool {
        let codeIndicators = ["func ", "let ", "var ", "const ", "import ", "def ", "class ", "return ", "if (", "=>", "{}", "()", "console.log", "public ", "private "]
        return codeIndicators.contains { text.contains($0) } || text.contains("\n") && text.contains("    ")
    }
    
    public func copyToPasteboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let data = item.imageData, let img = NSImage(data: data) {
            pasteboard.writeObjects([img])
        } else {
            pasteboard.setString(item.textContent, forType: .string)
        }
        self.lastChangeCount = pasteboard.changeCount
        NSSound(named: "Pop")?.play()
    }
    
    public func deleteItem(id: UUID) {
        items.removeAll { $0.id == id }
    }
    
    public func clearAll() {
        items.removeAll()
        NSSound(named: "Tink")?.play()
    }
    
    public var filteredItems: [ClipboardItem] {
        guard let filter = selectedFilter else { return items }
        return items.filter { $0.type == filter }
    }
}
