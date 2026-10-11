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

    static var zapnuto: Bool {
        get { UserDefaults.standard.bool(forKey: klicZapnuto) }
        set { UserDefaults.standard.set(newValue, forKey: klicZapnuto) }
    }

    /// Zapne/vypne oznámení. Vrací, jestli jsou po změně zapnutá.
    static func nastav(_ zapnout: Bool) async -> Bool {
        if !zapnout {
            zapnuto = false
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskID)
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
        let req = BGAppRefreshTaskRequest(identifier: taskID)
        req.earliestBeginDate = Date(timeIntervalSinceNow: 3 * 3600)
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

    /// Porovná nejnovější číslo na webu s posledním známým a případně pošle upozornění.
    static func kontrola() async {
        guard zapnuto, let nejnovejsi = (try? await CislaStore.nactiSeznam())?.first else { return }
        let posledni = UserDefaults.standard.integer(forKey: klicPosledni)
        if posledni == 0 {
            UserDefaults.standard.set(nejnovejsi.poradi, forKey: klicPosledni)
            return
        }
        guard nejnovejsi.poradi > posledni else { return }
        UserDefaults.standard.set(nejnovejsi.poradi, forKey: klicPosledni)
        let obsah = UNMutableNotificationContent()
        obsah.title = "Nový Mimoník"
        obsah.body = "Vyšlo číslo \(nejnovejsi.nazev). Klepni a přečti si ho."
        obsah.sound = .default
        let req = UNNotificationRequest(identifier: "cislo-\(nejnovejsi.id)", content: obsah, trigger: nil)
        try? await UNUserNotificationCenter.current().add(req)
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
