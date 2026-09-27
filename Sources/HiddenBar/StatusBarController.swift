import AppKit
import ServiceManagement

/// Gère les deux items de la barre des menus :
///  - `toggleItem`    : le chevron cliquable (le plus à droite)
///  - `separatorItem` : la barre « | ». Tout ce qui est à sa GAUCHE est caché.
///
/// Pour cacher, on élargit le séparateur jusqu'à ce qu'il déborde.
/// Sur macOS 27, `MenuBarAgent` dessine la barre : un item qui déborde est retiré
/// avec tous ceux à sa gauche. Mais un item plus large que la moitié de l'écran
/// est ignoré tout seul → d'où une largeur juste sous cette limite, pas 10 000.
final class StatusBarController {
    private let toggleItem: NSStatusItem
    private let separatorItem: NSStatusItem

    private let separatorVisibleLength: CGFloat = 8
    /// Padding ajouté par MenuBarAgent autour de chaque item (mesuré : ~16 pt).
    private let agentItemPadding: CGFloat = 16

    private var autoCollapseTimer: Timer?

    private(set) var isCollapsed = false {
        didSet { updateAppearance() }
    }

    init() {
        // Créé en premier → placé le plus à droite.
        toggleItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        toggleItem.autosaveName = "hiddenbar_toggle"

        separatorItem = NSStatusBar.system.statusItem(withLength: separatorVisibleLength)
        separatorItem.autosaveName = "hiddenbar_separator"

        if let button = toggleItem.button {
            button.target = self
            button.action = #selector(toggleClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        if let button = separatorItem.button {
            button.image = NSImage(systemSymbolName: "poweron", accessibilityDescription: "Séparateur")
            button.imageScaling = .scaleProportionallyDown
        }

        updateAppearance()
        // Cache au démarrage (légèrement différé : les positions doivent être connues).
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.collapse()
        }
    }

    // MARK: - Actions

    @objc private func toggleClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true

        if isRightClick {
            showMenu()
        } else {
            isCollapsed ? expand() : collapse()
        }
    }

    func collapse() {
        guard canCollapse() else { return }
        autoCollapseTimer?.invalidate()
        separatorItem.length = collapsedLength()
        isCollapsed = true
    }

    /// Avant MenuBarAgent (macOS < 27), un séparateur géant pousse simplement
    /// les icônes hors de l'écran. Avec MenuBarAgent, la largeur max acceptée
    /// est la moitié de l'écran (padding compris).
    private func collapsedLength() -> CGFloat {
        let hasMenuBarAgent = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.MenuBarAgent").isEmpty == false
        guard hasMenuBarAgent else { return 10_000 }

        let screen = separatorItem.button?.window?.screen ?? NSScreen.main
        let screenWidth = screen?.frame.width ?? 1440
        return screenWidth / 2 - agentItemPadding - 8
    }

    func expand() {
        separatorItem.length = separatorVisibleLength
        isCollapsed = false
        scheduleAutoCollapse()
    }

    /// Sécurité : si l'utilisateur a placé le séparateur À DROITE du chevron,
    /// l'élargir cacherait le chevron lui-même → plus moyen de réafficher.
    private func canCollapse() -> Bool {
        guard let toggleX = toggleItem.button?.window?.frame.minX,
              let separatorX = separatorItem.button?.window?.frame.minX
        else { return false }
        return separatorX < toggleX
    }

    private func scheduleAutoCollapse() {
        autoCollapseTimer?.invalidate()
        guard let delay = autoCollapseDelay() else { return }
        autoCollapseTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.collapse()
        }
    }

    /// Délai avant que les icônes se recachent automatiquement après un expand.
    /// Retourne `nil` pour désactiver le masquage automatique.
    private func autoCollapseDelay() -> TimeInterval? {
        // Désactivé pour l'instant : les icônes restent visibles jusqu'au prochain clic.
        return nil
    }

    // MARK: - Apparence

    private func updateAppearance() {
        let symbol = isCollapsed ? "chevron.left" : "chevron.right"
        toggleItem.button?.image = NSImage(
            systemSymbolName: symbol,
            accessibilityDescription: isCollapsed ? "Afficher les icônes" : "Cacher les icônes"
        )
        // Le séparateur n'est utile visuellement que lorsque tout est déplié.
        separatorItem.button?.alphaValue = isCollapsed ? 0 : 1
    }

    // MARK: - Menu clic droit

    private func showMenu() {
        let menu = NSMenu()

        let login = NSMenuItem(title: "Lancer au démarrage", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        let help = NSMenuItem(title: "⌘ + glisser une icône à gauche de « / » pour la cacher", action: nil, keyEquivalent: "")
        help.isEnabled = false
        menu.addItem(help)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quitter HiddenBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        // Affiche le menu sous le chevron, puis le détache pour que le clic gauche reste un toggle.
        toggleItem.menu = menu
        toggleItem.button?.performClick(nil)
        toggleItem.menu = nil
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("HiddenBar: launch at login error: \(error)")
        }
    }
}
