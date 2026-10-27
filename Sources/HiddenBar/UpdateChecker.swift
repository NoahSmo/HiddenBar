import AppKit

/// Compare la version installée à la dernière release GitHub.
/// Ne télécharge rien : indique seulement qu'une mise à jour existe
/// et ouvre la page de la release (`brew upgrade` ou zip).
final class UpdateChecker {
    struct Release {
        let version: String
        let url: URL
    }

    private let latestReleaseAPI = URL(string: "https://api.github.com/repos/NoahSmo/HiddenBar/releases/latest")!
    private let lastCheckKey = "lastUpdateCheck"
    private let checkInterval: TimeInterval = 24 * 3600

    /// Dernière release plus récente que l'app installée, sinon `nil`.
    private(set) var availableUpdate: Release?

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Vérification au lancement, au plus une fois par jour.
    func checkIfDue() {
        let last = UserDefaults.standard.object(forKey: lastCheckKey) as? Date
        guard last == nil || Date().timeIntervalSince(last!) > checkInterval else { return }
        check(completion: nil)
    }

    /// Vérification immédiate. `completion` reçoit `false` en cas d'erreur réseau,
    /// sinon `true` ; `availableUpdate` est alors à jour (`nil` si l'app est à jour).
    func check(completion: ((Bool) -> Void)?) {
        var request = URLRequest(url: latestReleaseAPI, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self else { return }
            guard error == nil, let data, let release = self.parse(data) else {
                DispatchQueue.main.async { completion?(false) }
                return
            }
            DispatchQueue.main.async {
                UserDefaults.standard.set(Date(), forKey: self.lastCheckKey)
                self.availableUpdate = Self.isVersion(release.version, newerThan: self.currentVersion) ? release : nil
                completion?(true)
            }
        }.resume()
    }

    func openReleasePage() {
        let url = availableUpdate?.url ?? URL(string: "https://github.com/NoahSmo/HiddenBar/releases/latest")!
        NSWorkspace.shared.open(url)
    }

    private func parse(_ data: Data) -> Release? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let page = json["html_url"] as? String,
              let url = URL(string: page),
              url.scheme == "https",
              url.host == "github.com"
        else { return nil }
        return Release(version: tag.hasPrefix("v") ? String(tag.dropFirst()) : tag, url: url)
    }

    /// Comparaison numérique composant par composant : « 1.10.0 » > « 1.9.0 ».
    static func isVersion(_ a: String, newerThan b: String) -> Bool {
        a.compare(b, options: .numeric) == .orderedDescending
    }
}
