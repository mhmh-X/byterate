import AppKit

@main
@MainActor
enum Main {
    private static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // 只在菜单栏显示，不出现在 Dock
        app.run()
    }
}
