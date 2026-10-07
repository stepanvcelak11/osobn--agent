import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass
import AgentCore

/// Delegát aplikace – jen kvůli bezpečnostním pojistkám.
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Zákaz klávesnic třetích stran: mohly by odesílat psaný text na internet. Funguje jen systémová klávesnice iOS.
    func application(_ application: UIApplication,
                     shouldAllowExtensionPointIdentifier extensionPointIdentifier: UIApplication.ExtensionPointIdentifier) -> Bool {
        extensionPointIdentifier != .keyboard
    }
}

@main
struct OsobniAgentApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var app = AppModel()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearance") private var appearance: String = AppearanceMode.dark.rawValue
    @AppStorage("textScale") private var textScale: Int = -1

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .environmentObject(app.models)
                .environmentObject(app.ai)
                .environmentObject(app.recorder)
                .environmentObject(app.speaker)
                .environmentObject(app.notifications)
                .environmentObject(app.clock)
                .environmentObject(app.apple)
                .environmentObject(app.longRecorder)
                .environmentObject(app.processor)
                .preferredColorScheme(AppearanceMode(rawValue: appearance)?.scheme)
                .dynamicTypeSize(textScale < 0 ? DynamicTypeSize.xSmall...DynamicTypeSize.accessibility5
                                 : TextScale.sizes[min(textScale, TextScale.sizes.count - 1)]...TextScale.sizes[min(textScale, TextScale.sizes.count - 1)])
                .environment(\.locale, Locale(identifier: "cs_CZ"))
                .environment(\.calendar, CzechFormat.calendar())
                .onAppear { app.start() }
                .onOpenURL { app.handleURL($0) }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                    app.ai.handleMemoryWarning()
                }
        }
        .onChange(of: scenePhase) { _, p in app.scenePhaseChanged(p) }
    }
}

/// Brána: onboarding → zámek → aplikace. Překrytí obsahu mimo popředí a při nahrávání obrazovky.
struct RootView: View {
    @EnvironmentObject var app: AppModel
    @State private var screenCaptured = UIScreen.main.isCaptured

    var body: some View {
        ZStack {
            switch app.phase {
            case .launching:
                Color(.systemBackground).ignoresSafeArea()
            case .onboarding:
                OnboardingView()
            case .locked:
                LockView()
            case .unlocked:
                MainView()
                    .overlay(ActivityTracker { app.noteActivity() }.allowsHitTesting(false))
            case .wiped:
                WipedView()
            }
            if app.shieldVisible || screenCaptured {
                PrivacyShield(recording: screenCaptured && !app.shieldVisible)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: app.phase)
        .onReceive(NotificationCenter.default.publisher(for: .quickCaptureRequested)) { _ in
            app.consumePendingCaptureFlag()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
            screenCaptured = UIScreen.main.isCaptured
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
            if app.phase == .unlocked {
                app.toast = Toast(text: "Pozor: snímek obrazovky může obsahovat osobní data a uloží se do Fotek.")
            }
        }
    }
}

/// Překrytí obsahu v přepínači aplikací a při nahrávání/zrcadlení obrazovky.
struct PrivacyShield: View {
    var recording: Bool
    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.09, blue: 0.16).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: recording ? "record.circle" : "lock.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(recording ? "Obsah je skrytý během nahrávání obrazovky" : "Osobní agent")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Zaznamenává doteky (pro automatické zamčení po nečinnosti), aniž by je zachytával.
struct ActivityTracker: UIViewRepresentable {
    var onActivity: () -> Void
    func makeUIView(context: Context) -> TrackerView {
        let v = TrackerView()
        v.onActivity = onActivity
        return v
    }
    func updateUIView(_ uiView: TrackerView, context: Context) { uiView.onActivity = onActivity }

    final class TrackerView: UIView {
        var onActivity: (() -> Void)?
        private var gesture: UITapGestureRecognizer?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let window, gesture == nil else { return }
            let g = ActivityGesture(target: self, action: #selector(noop))
            g.onTouch = { [weak self] in self?.onActivity?() }
            g.cancelsTouchesInView = false
            g.delaysTouchesBegan = false
            g.delaysTouchesEnded = false
            window.addGestureRecognizer(g)
            gesture = g
        }
        @objc private func noop() {}
        override func removeFromSuperview() {
            if let g = gesture { g.view?.removeGestureRecognizer(g) }
            super.removeFromSuperview()
        }
    }

    final class ActivityGesture: UITapGestureRecognizer {
        var onTouch: (() -> Void)?
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            onTouch?()
            state = .failed
        }
    }
}

struct WipedView: View {
    @EnvironmentObject var app: AppModel
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "trash.circle.fill").font(.system(size: 60)).foregroundStyle(.red)
            Text("Data byla smazána").font(.title2.bold())
            Text("Šifrovací klíče byly zničeny a databáze odstraněna. Data už nejde obnovit jinak než ze zálohy.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Začít znovu") { app.restartAfterWipe() }.buttonStyle(.borderedProminent)
        }
        .padding(32)
    }
}
