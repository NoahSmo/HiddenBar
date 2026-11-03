import AppKit
import ServiceManagement

/// Deux items dans la barre des menus :
///  - `toggleItem`    : le chevron cliquable (le plus à droite)
///  - `separatorItem` : la barre « | ». Tout ce qui est à sa GAUCHE est caché.
///
/// Replié, le séparateur est élargi jusqu'à déborder : tout ce qui est à sa
/// gauche est poussé hors de la barre. Déplié, il revient à 8 pt.
final class StatusBarController {
    private let toggleItem: NSStatusItem
    private let separatorItem: NSStatusItem
    private let separatorVisibleLength: CGFloat = 8
    /// Padding ajouté par MenuBarAgent autour de chaque item (mesuré : ~16 pt).
    private let agentItemPadding: CGFloat = 16

    private var autoCollapseTimer: Timer?
    private let updateChecker = UpdateChecker()

    private(set) var isCollapsed = false {
        didSet { updateAppearance() }
    }

    init() {
        // Créé en premier → placé le plus à droite.
        toggleItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        toggleItem.autosaveName = "hiddenbar_toggle"
        // `isVisible` est persisté avec l'autosaveName : sans ça, quitter l'app
        // repliée relancerait sans chevron.
        toggleItem.isVisible = true

        separatorItem = NSStatusBar.system.statusItem(withLength: separatorVisibleLength)
        separatorItem.autosaveName = "hiddenbar_separator_v3"

        if let button = toggleItem.button {
            button.target = self
            button.action = #selector(toggleClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        separatorItem.button?.imageScaling = .scaleProportionallyDown

        updateAppearance()
        // Cache au démarrage (légèrement différé : les positions doivent être connues).
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.collapse()
        }
        updateChecker.checkIfDue()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, self.isCollapsed else { return }
            self.applyCollapsedLayout()
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
        applyCollapsedLayout()
        isCollapsed = true
    }

    /// Sans MenuBarAgent (macOS < 27) : séparateur énorme. Avec : MenuBarAgent ignore
    /// un item plus large que la moitié de l'écran, on prend donc juste en dessous.
    private func applyCollapsedLayout() {
        guard hasMenuBarAgent else {
            separatorItem.length = 10_000
            return
        }
        let screen = separatorItem.button?.window?.screen ?? NSScreen.main
        let width = screen?.frame.width ?? 1440
        separatorItem.length = width / 2 - agentItemPadding - 8
    }

    private var hasMenuBarAgent: Bool {
        NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.MenuBarAgent").isEmpty == false
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
        // On change l'image plutôt que alphaValue : MenuBarAgent ne rafraîchit pas
        // toujours le rendu d'un item sur un simple changement d'opacité.
        separatorItem.button?.image = isCollapsed ? nil : NSImage(
            systemSymbolName: "poweron", accessibilityDescription: "Séparateur"
        )
        // Toujours visible : le chevron natif de MenuBarAgent n'appelle pas expand(),
        // le cacher laissait l'utilisateur sans moyen de rouvrir.
        toggleItem.isVisible = true
    }

    // MARK: - Menu clic droit

    private func showMenu() {
        let menu = NSMenu()

        let login = NSMenuItem(title: "Lancer au démarrage", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        if let update = updateChecker.availableUpdate {
            let item = NSMenuItem(title: "Mise à jour disponible : v\(update.version)", action: #selector(openUpdate), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        } else {
            let item = NSMenuItem(title: "Rechercher des mises à jour…", action: #selector(checkForUpdates), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let help = NSMenuItem(title: "⌘ + glisser une icône à gauche de « | » pour la cacher, à droite pour la garder", action: nil, keyEquivalent: "")
        help.isEnabled = false
        menu.addItem(help)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quitter HiddenBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        // Affiche le menu sous le chevron, puis le détache pour que le clic gauche reste un toggle.
        toggleItem.menu = menu
        toggleItem.button?.performClick(nil)
        toggleItem.menu = nil
    }

    @objc private func openUpdate() {
        updateChecker.openReleasePage()
    }

    @objc private func checkForUpdates() {
        updateChecker.check { [weak self] success in
            guard let self else { return }
            let alert = NSAlert()
            if !success {
                alert.messageText = "Impossible de vérifier les mises à jour"
                alert.informativeText = "Vérifie ta connexion et réessaie."
            } else if let update = self.updateChecker.availableUpdate {
                alert.messageText = "HiddenBar \(update.version) est disponible"
                alert.informativeText = "Version installée : \(self.updateChecker.currentVersion).\nMise à jour : brew upgrade --cask hiddenbar, ou télécharge le zip."
                alert.addButton(withTitle: "Télécharger")
                alert.addButton(withTitle: "Plus tard")
            } else {
                alert.messageText = "HiddenBar est à jour"
                alert.informativeText = "Version \(self.updateChecker.currentVersion)."
            }
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn, self.updateChecker.availableUpdate != nil {
                self.updateChecker.openReleasePage()
            }
        }
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
