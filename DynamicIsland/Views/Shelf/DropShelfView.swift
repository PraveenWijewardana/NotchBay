import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct DropShelfView: View {
    @ObservedObject public var viewModel: NotchViewModel
    @ObservedObject private var shelfService: DropShelfService
    
    public init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        self.shelfService = viewModel.shelfService
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // MARK: - Top Filter & Action Bar
            topFilterBar
                .padding(.horizontal, 4)
            
            // MARK: - Cards Zone / Drop Target
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        shelfService.isTargeted ? Color.yellow : Color.white.opacity(0.12),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(shelfService.isTargeted ? Color.yellow.opacity(0.08) : Color.white.opacity(0.02))
                    )
                
                if shelfService.filteredItems.isEmpty {
                    emptyShelfView
                } else {
                    cardsScrollView
                }
            }
            .frame(height: 146)
            .onDrop(of: [.fileURL, .text, .image], isTargeted: Binding(
                get: { shelfService.isTargeted },
                set: { shelfService.isTargeted = $0 }
            )) { providers in
                for provider in providers {
                    if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                        _ = provider.loadObject(ofClass: URL.self) { url, _ in
                            if let url = url {
                                Task { @MainActor in
                                    shelfService.addFile(url: url)
                                }
                            }
                        }
                    } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                        _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                            if let data = data {
                                Task { @MainActor in
                                    let formatter = DateFormatter()
                                    formatter.dateFormat = "HH.mm.ss"
                                    shelfService.addImage(data: data, name: "Dropped Image \(formatter.string(from: Date())).png")
                                }
                            }
                        }
                    } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                        _ = provider.loadObject(ofClass: String.self) { text, _ in
                            if let text = text {
                                Task { @MainActor in
                                    shelfService.addText(text)
                                }
                            }
                        }
                    }
                }
                return true
            }
        }
    }
    
    // MARK: - Top Filter Bar
    private var topFilterBar: some View {
        HStack(spacing: 6) {
            // Horizontally Scrollable Category Pills (Single line, strictly no wrapping)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    filterPill(type: .all, title: "All", icon: nil)
                    filterPill(type: .link, title: "Links", icon: "link")
                    filterPill(type: .color, title: "Colors", icon: "paintpalette.fill")
                    filterPill(type: .image, title: "Images", icon: "photo.fill")
                    filterPill(type: .code, title: "Code", icon: "chevron.left.forwardslash.chevron.right")
                    filterPill(type: .text, title: "Text", icon: "line.3.horizontal")
                }
            }
            
            Spacer(minLength: 4)
            
            // Toast notification pill if active
            if let toast = shelfService.toastMessage {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.green)
                    Text(toast)
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color(white: 0.22))
                .clipShape(Capsule())
                .transition(.opacity)
                .fixedSize()
            }
            
            // Stepper Pill (< 1/1 >)
            stepperPill
            
            // Paste Capsule Button
            Button {
                shelfService.pasteFromClipboard()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 9, weight: .semibold))
                    Text("Paste")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundColor(.black)
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(Color.yellow)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("v", modifiers: .command)
            .help("Paste from clipboard (⌘V)")
            .fixedSize()
            
            // AirDrop Capsule Button
            Button {
                if !shelfService.items.isEmpty {
                    shelfService.airDropAll()
                } else {
                    shelfService.airDropClipboard()
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "airdrop")
                        .font(.system(size: 9.5, weight: .semibold))
                    Text("AirDrop")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(Color.blue.opacity(0.85))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Send vault items or clipboard via AirDrop")
            .fixedSize()
            
            // Clear All Button
            if !shelfService.items.isEmpty {
                Button {
                    shelfService.clearAll()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.45))
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help("Clear shelf")
                .fixedSize()
            }
        }
    }
    
    // MARK: - Filter Pill
    private func filterPill(type: ShelfItemType, title: String, icon: String?) -> some View {
        let isSelected = (shelfService.selectedFilter == type)
        
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                shelfService.selectedFilter = type
            }
        } label: {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 9.5, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 10.5, weight: isSelected ? .bold : .semibold, design: .rounded))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: true)
            }
            .foregroundColor(isSelected ? .black : .white.opacity(0.85))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(isSelected ? Color.white : Color(white: 0.16))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
    }
    
    // MARK: - Stepper Pill
    private var stepperPill: some View {
        let count = shelfService.filteredItems.count
        let total = max(1, count)
        let text = count > 0 ? "1/\(total)" : "0"
        
        return HStack(spacing: 4) {
            Image(systemName: "chevron.left")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
            
            Text(text)
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
            
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background(Color(white: 0.16))
        .clipShape(Capsule())
    }
    
    // MARK: - Empty State
    private var emptyShelfView: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 22))
                .foregroundColor(.secondary.opacity(0.8))
            
            if shelfService.items.isEmpty {
                Text("Drop files, images, links, or colors here")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text("Or click Paste to grab anything from your clipboard")
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            } else {
                Text("No \(shelfService.selectedFilter.rawValue) in shelf")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Button {
                    shelfService.selectedFilter = .all
                } label: {
                    Text("Show All Items")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(.yellow)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Cards Scroll View
    private var cardsScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(shelfService.filteredItems) { item in
                    shelfPreviewCard(item: item)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }
    
    // MARK: - Vertical Visual Preview Card
    private func shelfPreviewCard(item: ShelfItem) -> some View {
        let isCopied = (shelfService.copiedItemId == item.id)
        let isHovered = (shelfService.hoveredItemId == item.id)
        
        return ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // Top Visual Preview Area (Height ~104pt)
                cardTopPreview(item: item)
                    .frame(width: 106, height: 104)
                    .clipped()
                
                // Bottom Badge & Time Bar (Height ~28pt)
                cardBottomBar(item: item)
                    .frame(width: 106, height: 28)
                    .background(Color(red: 0.04, green: 0.04, blue: 0.05))
            }
            .frame(width: 106, height: 132)
            .background(Color(red: 0.09, green: 0.09, blue: 0.11))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(
                        isCopied ? Color.green : (isHovered ? Color.white.opacity(0.3) : Color.white.opacity(0.1)),
                        lineWidth: isCopied ? 2 : 1
                    )
            )
            .scaleEffect(isCopied ? 1.03 : 1.0)
            
            // Hover Overlay Actions: Open & Delete
            if isHovered {
                HStack(spacing: 3) {
                    // Open / Reveal in Finder button
                    Button {
                        if item.path != nil {
                            shelfService.revealInFinder(id: item.id)
                        } else {
                            shelfService.openItem(id: item.id)
                        }
                    } label: {
                        Image(systemName: item.path != nil ? "arrow.up.forward.app" : "arrow.up.right")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(.white)
                            .padding(3.5)
                            .background(Color.black.opacity(0.65))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(item.path != nil ? "Reveal in Finder" : "Open")
                    
                    // AirDrop button
                    Button {
                        shelfService.airDropItem(id: item.id)
                    } label: {
                        Image(systemName: "airdrop")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(.white)
                            .padding(3.5)
                            .background(Color.blue.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Share via AirDrop")
                    
                    // Remove button
                    Button {
                        shelfService.removeItem(id: item.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(3.5)
                            .background(Color.black.opacity(0.65))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Remove from shelf")
                }
                .padding(5)
                .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            shelfService.hoveredItemId = hovering ? item.id : nil
        }
        .onTapGesture {
            shelfService.copyItemToClipboard(id: item.id)
        }
        // Drag OUT of shelf to Finder, browser, or any other app
        .onDrag {
            if let path = item.path {
                return NSItemProvider(object: path as NSURL)
            } else if let hex = item.colorHex {
                return NSItemProvider(object: hex as NSString)
            } else if let imgData = item.imageData, item.itemType == .image, let img = NSImage(data: imgData) {
                return NSItemProvider(object: img)
            } else if let text = item.stringContent {
                return NSItemProvider(object: text as NSString)
            }
            return NSItemProvider(object: item.name as NSString)
        }
        .contextMenu {
            Button {
                shelfService.copyItemToClipboard(id: item.id)
            } label: {
                Label("Copy to Clipboard", systemImage: "doc.on.doc")
            }
            
            Button {
                shelfService.airDropItem(id: item.id)
            } label: {
                Label("Share via AirDrop...", systemImage: "airdrop")
            }
            
            if item.path != nil {
                Button {
                    shelfService.revealInFinder(id: item.id)
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
                
                Button {
                    shelfService.openItem(id: item.id)
                } label: {
                    Label("Open File", systemImage: "arrow.up.forward.app")
                }
            } else if item.itemType == .link {
                Button {
                    shelfService.openItem(id: item.id)
                } label: {
                    Label("Open Link in Browser", systemImage: "safari")
                }
            }
            
            Divider()
            
            Button(role: .destructive) {
                shelfService.removeItem(id: item.id)
            } label: {
                Label("Remove from Shelf", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Card Top Preview Content
    @ViewBuilder
    private func cardTopPreview(item: ShelfItem) -> some View {
        switch item.itemType {
        case .image:
            if let data = item.imageData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 106, height: 104)
                    .clipped()
            } else {
                ZStack {
                    Color(red: 0.12, green: 0.12, blue: 0.14)
                    Image(systemName: "photo.fill")
                        .font(.system(size: 26))
                        .foregroundColor(item.itemType.badgeColor)
                }
            }
            
        case .color:
            let hex = item.colorHex ?? item.name
            let bgColor = colorFromHex(hex)
            let textColor = contrastTextColor(for: hex)
            
            ZStack {
                bgColor
                
                Text(hex)
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundColor(textColor)
                    .padding(.horizontal, 4)
            }
            
        case .link:
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "link")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(item.itemType.badgeColor)
                
                Spacer(minLength: 0)
                
                Text(item.name)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(9)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
        case .text:
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(item.itemType.badgeColor)
                
                Spacer(minLength: 0)
                
                Text(item.stringContent ?? item.name)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(9)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
        case .code:
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(item.itemType.badgeColor)
                
                Spacer(minLength: 0)
                
                Text(item.stringContent ?? item.name)
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(9)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
        case .file, .all:
            VStack(spacing: 4) {
                Spacer(minLength: 0)
                
                if let data = item.imageData, let img = NSImage(data: data) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                } else {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 30))
                        .foregroundColor(item.itemType.badgeColor)
                }
                
                Spacer(minLength: 0)
                
                Text(item.name)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 4)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Card Bottom Bar (Badge & Time)
    private func cardBottomBar(item: ShelfItem) -> some View {
        HStack(spacing: 4) {
            Text(item.itemType.badgeTitle)
                .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                .foregroundColor(item.itemType.badgeColor)
            
            Spacer(minLength: 0)
            
            Text(item.timeAgoFormatted)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(.gray.opacity(0.85))
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - Color Contrast & Hex Helpers
    private func contrastTextColor(for hex: String) -> Color {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("#") { clean.removeFirst() }
        var rgb: UInt64 = 0
        guard Scanner(string: clean).scanHexInt64(&rgb) else { return .white }
        let r, g, b: Double
        if clean.count == 6 || clean.count == 8 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
        } else if clean.count == 3 {
            let rInt = (rgb & 0xF00) >> 8
            let gInt = (rgb & 0x0F0) >> 4
            let bInt = rgb & 0x00F
            r = Double(rInt | (rInt << 4)) / 255.0
            g = Double(gInt | (gInt << 4)) / 255.0
            b = Double(bInt | (bInt << 4)) / 255.0
        } else {
            return .white
        }
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.62 ? .black : .white
    }
    
    private func colorFromHex(_ hex: String) -> Color {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("#") { clean.removeFirst() }
        var rgb: UInt64 = 0
        guard Scanner(string: clean).scanHexInt64(&rgb) else { return Color.gray }
        let r, g, b: Double
        if clean.count == 6 || clean.count == 8 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
        } else if clean.count == 3 {
            let rInt = (rgb & 0xF00) >> 8
            let gInt = (rgb & 0x0F0) >> 4
            let bInt = rgb & 0x00F
            r = Double(rInt | (rInt << 4)) / 255.0
            g = Double(gInt | (gInt << 4)) / 255.0
            b = Double(bInt | (bInt << 4)) / 255.0
        } else {
            return Color.gray
        }
        return Color(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}
