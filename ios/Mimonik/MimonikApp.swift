import SwiftUI
import BackgroundTasks
import UserNotifications

@main
struct MimonikApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = CislaStore()

    init() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Notifier.taskID, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            Notifier.zpracujUlohu(task)
        }
        UNUserNotificationCenter.current().delegate = Notifier.shared
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
        }
        .onChange(of: scenePhase) { faze in
            if faze == .active {
                Task { await store.obnov() }
            } else if faze == .background {
                Notifier.naplanujKontrolu()
            }
        }
    }
}
