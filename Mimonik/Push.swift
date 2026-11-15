import UIKit

/// Vzdálené (APNs) upozornění: appka pošle token zařízení na web Mimoníku a ten pošle push, když vyjde nové číslo.
/// Místní kontrola na pozadí zůstává jen jako záloha a pro automatické stažení čísla.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
        let hex = token.map { String(format: "%02x", $0) }.joined()
        Task { await Push.posli(token: hex, zapnout: true) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Push.registrovano = false
    }
}

enum Push {
    private static let klicRegistrovano = "pushRegistrovano"

    /// True, když server potvrdil token zařízení; pak se místní upozornění neposílá (přišlo by dvakrát).
    static var registrovano: Bool {
        get { UserDefaults.standard.bool(forKey: klicRegistrovano) }
        set { UserDefaults.standard.set(newValue, forKey: klicRegistrovano) }
    }

    #if DEBUG
    private static let prostredi = "sandbox"
    #else
    private static let prostredi = "production"
    #endif

    /// Požádá iOS o token zařízení (jen když jsou upozornění zapnutá).
    @MainActor static func registruj() {
        guard Notifier.zapnuto else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    @MainActor static func odregistruj() {
        UIApplication.shared.unregisterForRemoteNotifications()
        if let token = UserDefaults.standard.string(forKey: "pushToken") {
            Task { await posli(token: token, zapnout: false) }
        }
        registrovano = false
    }

    static func posli(token: String, zapnout: Bool) async {
        if zapnout { UserDefaults.standard.set(token, forKey: "pushToken") }
        let telo = try? JSONSerialization.data(withJSONObject: ["token": token, "env": prostredi])
        for adresa in Config.adresy {
            guard let url = URL(string: adresa + (zapnout ? "apns/register" : "apns/unregister")) else { continue }
            var req = URLRequest(url: url, timeoutInterval: 20)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = telo
            guard let (_, odpoved) = try? await URLSession.shared.data(for: req),
                  (odpoved as? HTTPURLResponse)?.statusCode == 200 else { continue }
            if zapnout { registrovano = true }
            return
        }
        if zapnout { registrovano = false }
    }
}
