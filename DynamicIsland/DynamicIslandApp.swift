import AppKit

@main
public struct DynamicIslandApp {
    @MainActor
    public static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
