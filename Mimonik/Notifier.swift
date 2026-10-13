import Foundation
import UIKit
import BackgroundTasks
import UserNotifications

/// Upozornění na nové číslo. Zdarma účet Apple neumí vzdálený push (APNs), proto appka
/// sama v pozadí občas zkontroluje web a pošle místní upozornění.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()
    static let taskID = "tl.knyt.Mimonik.refresh"
    private static let klicZapnuto = "oznameniZapnuta"
    private static let klicPosledni = "posledniZnameCislo"
    private static let klicTicho = "tichoZapnuto"
    private static let klicTichoOd = "tichoOd"
    private static let klicTichoDo = "tichoDo"
    private static let klicInterval = "intervalHodin"
    private static let klicAutoStahovat = "autoStahovat"
    private static let klicJenWifi = "autoStahovatJenWifi"

    static let intervaly = [1, 3, 6, 12]

    /// Interval kontroly v hodinách.
    static var interval: Int {
        get { let i = UserDefaults.standard.integer(forKey: klicInterval); return i == 0 ? 3 : i }
        set { UserDefaults.standard.set(newValue, forKey: klicInterval) }
    }

    /// Automaticky stáhnout nové číslo (výchozí zapnuto).
    static var autoStahovat: Bool {
        get { UserDefaults.standard.object(forKey: klicAutoStahovat) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: klicAutoStahovat) }
    }

    /// Automatické stahování jen přes Wi-Fi (výchozí zapnuto).
    static var jenWifi: Bool {
        get { UserDefaults.standard.object(forKey: klicJenWifi) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: klicJenWifi) }
    }

    /// Stáhne PDF čísla, pokud je automatické stahování zapnuté. Vrací, jestli je číslo po volání v zařízení.
    static func autoStahni(_ cislo: Cislo) async -> Bool {
        if CislaStore.souborPDF(cislo).exists { return true }
        guard autoStahovat else { return false }
        return (try? await CislaStore.stahniPDF(cislo, jenWifi: jenWifi)) != nil
    }

    static var tichoZapnuto: Bool {
        get { UserDefaults.standard.bool(forKey: klicTicho) }
        set { UserDefaults.standard.set(newValue, forKey: klicTicho) }
    }

    /// Začátek tichých hodin, minuty od půlnoci (výchozí 22:00).
    static var tichoOd: Int {
        get { UserDefaults.standard.object(forKey: klicTichoOd) as? Int ?? 22 * 60 }
        set { UserDefaults.standard.set(newValue, forKey: klicTichoOd) }
    }

    /// Konec tichých hodin, minuty od půlnoci (výchozí 7:00).
    static var tichoDo: Int {
        get { UserDefaults.standard.object(forKey: klicTichoDo) as? Int ?? 7 * 60 }
        set { UserDefaults.standard.set(newValue, forKey: klicTichoDo) }
    }

    static func jeTicho(_ kdy: Date = Date()) -> Bool {
        guard tichoZapnuto, tichoOd != tichoDo else { return false }
        let c = Calendar.current.dateComponents([.hour, .minute], from: kdy)
        let n = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        return tichoOd < tichoDo ? (n >= tichoOd && n < tichoDo) : (n >= tichoOd || n < tichoDo)
    }

    /// Odznak na ikoně = počet nepřečtených čísel (při vypnutých upozorněních žádný).
    static func aktualizujOdznak(_ cisla: [Cislo]) {
        let pocet = zapnuto ? Stav.pocetNeprectenych(cisla) : 0
        DispatchQueue.main.async { UIApplication.shared.applicationIconBadgeNumber = pocet }
    }

    static var zapnuto: Bool {
        get { UserDefaults.standard.bool(forKey: klicZapnuto) }
        set { UserDefaults.standard.set(newValue, forKey: klicZapnuto) }
    }

    /// Zapne/vypne oznámení. Vrací, jestli jsou po změně zapnutá.
    static func nastav(_ zapnout: Bool) async -> Bool {
        if !zapnout {
            zapnuto = false
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskID)
            DispatchQueue.main.async { UIApplication.shared.applicationIconBadgeNumber = 0 }
            return false
        }
        let centrum = UNUserNotificationCenter.current()
        let ok = (try? await centrum.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        zapnuto = ok
        if ok {
            // aby se neoznamovala čísla, která už existují
            if UserDefaults.standard.integer(forKey: klicPosledni) == 0,
               let nejnovejsi = (try? await CislaStore.nactiSeznam())?.first {
                UserDefaults.standard.set(nejnovejsi.poradi, forKey: klicPosledni)
            }
            naplanujKontrolu()
        }
        return ok
    }

    static func povoleno() async -> Bool {
        let s = await UNUserNotificationCenter.current().notificationSettings()
        return s.authorizationStatus == .authorized || s.authorizationStatus == .provisional
    }

    static func naplanujKontrolu() {
        guard zapnuto else { return }
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskID)
        let req = BGAppRefreshTaskRequest(identifier: taskID)
        req.earliestBeginDate = Date(timeIntervalSinceNow: Double(interval) * 3600)
        try? BGTaskScheduler.shared.submit(req)
    }

    static func zpracujUlohu(_ task: BGAppRefreshTask) {
        naplanujKontrolu()
        let prace = Task {
            await kontrola()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { prace.cancel() }
    }

    /// Porovná nejnovější číslo na webu s posledním známým a případně pošle upozornění
    /// (mimo tiché hodiny). Při ruční kontrole upozornění neposílá, jen vrátí výsledek.
    /// Vrací: nil = web nedostupný, true = je nové číslo, false = nic nového.
    @discardableResult
    static func kontrola(rucne: Bool = false) async -> Bool? {
        guard rucne || zapnuto else { return nil }
        guard let seznam = try? await CislaStore.nactiSeznam(), let nejnovejsi = seznam.first else { return nil }
        aktualizujOdznak(seznam)
        let posledni = UserDefaults.standard.integer(forKey: klicPosledni)
        if posledni == 0 {
            UserDefaults.standard.set(nejnovejsi.poradi, forKey: klicPosledni)
            return false
        }
        guard nejnovejsi.poradi > posledni else { return false }
        UserDefaults.standard.set(nejnovejsi.poradi, forKey: klicPosledni)
        let stazeno = await autoStahni(nejnovejsi)
        guard zapnuto, !rucne, !jeTicho() else { return true }
        let pocet = Stav.pocetNeprectenych(seznam)
        let obsah = UNMutableNotificationContent()
        obsah.title = "Nový Mimoník"
        var text = pocet > 1
            ? "Vyšlo číslo \(nejnovejsi.nazev). Nepřečtených čísel: \(pocet)."
            : "Vyšlo číslo \(nejnovejsi.nazev). Klepni a přečti si ho."
        if stazeno { text += " Je stažené, přečteš ho i bez signálu." }
        obsah.body = text
        obsah.sound = .default
        obsah.badge = NSNumber(value: pocet)
        let req = UNNotificationRequest(identifier: "cislo-\(nejnovejsi.id)", content: obsah, trigger: nil)
        try? await UNUserNotificationCenter.current().add(req)
        return true
    }

    /// Čísla, o kterých už uživatel ví (otevřel appku), se neoznamují.
    static func oznacJakoVidene(_ cisla: [Cislo]) {
        guard let n = cisla.first?.poradi, n > UserDefaults.standard.integer(forKey: klicPosledni) else { return }
        UserDefaults.standard.set(n, forKey: klicPosledni)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
