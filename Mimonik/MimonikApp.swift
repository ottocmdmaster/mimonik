import SwiftUI
import BackgroundTasks
import UserNotifications

@main
struct MimonikApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = CislaStore()

    init() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Notifier.taskID, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            Notifier.zpracujUlohu(task)
        }
        UNUserNotificationCenter.current().delegate = Notifier.shared
        Sync.start()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
        }
        .onChange(of: scenePhase) { faze in
            if faze == .active {
                Push.registruj()
                Task {
                    await store.obnov()
                    Notifier.aktualizujOdznak(store.cisla)
                }
            } else if faze == .background {
                Notifier.aktualizujOdznak(store.cisla)
                Notifier.naplanujKontrolu()
            }
        }
    }
}
