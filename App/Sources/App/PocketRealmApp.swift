import SwiftUI
import UIKit
import RealmCore

/// Systém aplikaci probudí, když doběhne stahování na pozadí.
final class AppDelegate: NSObject, UIApplicationDelegate {
    static var backgroundCompletion: (() -> Void)?
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        AppDelegate.backgroundCompletion = completionHandler
    }
}

@main
struct PocketRealmApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var app = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .environmentObject(app.models)
                .environmentObject(app.ai)
                .environmentObject(app.speaker)
                .environmentObject(app.downloader)
                .preferredColorScheme(.dark)
                .tint(Theme.ember)
                .task {
                    app.models.cleanupPartial()
                    app.refreshSaves()
                    #if DEBUG
                    if SelfTest.requested { await SelfTest.run(app); return }
                    if let d = Demo.mode { app.openDemo(d) }
                    #endif
                    await app.loadModels()
                    app.downloader.startIfNeeded(models: app.models)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                    app.ai.handleMemoryWarning()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                app.session?.save()
                if let s = app.session?.state { Task { await RealmNotifications.reschedule(for: s) } }
            case .active:
                app.session?.refreshSimulation()
                app.downloader.startIfNeeded(models: app.models)
            default: break
            }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var app: AppModel

    var body: some View {
        ZStack {
            Theme.bg0.ignoresSafeArea()
            if let s = app.session {
                GameView(session: s)
                    .id(s.id)
                    .transition(.opacity.combined(with: .scale(scale: 1.03)))
            } else {
                TitleView()
                    .transition(.opacity)
            }
        }
    }
}
