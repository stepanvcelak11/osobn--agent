import SwiftUI
import AgentCore

struct OnboardingView: View {
    @EnvironmentObject var app: AppModel
    @State private var step = 0
    @State private var password = ""
    @State private var password2 = ""
    @State private var working = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if step == 0 { intro } else { passwordStep }
                }
                .padding(24)
            }
            .navigationTitle(step == 0 ? "Vítej" : "Nouzové heslo")
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "lock.shield.fill").font(.system(size: 54)).foregroundStyle(Theme.accent)
            Text("Tvůj osobní agent běží jen v tomto telefonu.").font(.title2.bold())
            feature("wifi.slash", "Žádný internet", "Aplikace nemá žádný síťový kód. Nic se nikam neposílá.")
            feature("cpu", "Lokální AI", "Jazykový model, přepis řeči i vyhledávání běží přímo v telefonu.")
            feature("lock.fill", "Šifrovaná data", "Vše je v databázi šifrované AES-256. Klíč chrání Secure Enclave a \(KeyManager.biometryDescription).")
            feature("icloud.slash", "Bez cloudových záloh", "Data jsou vyloučena ze záloh iCloud. Zálohu si můžeš kdykoli vytvořit – šifrovanou heslem.")
            if !DeviceIntegrity.hasPasscode {
                Label("Telefon nemá nastavený kód. Bez něj nelze data chránit – nastav ho v Nastavení iOS.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange).font(.subheadline)
            }
            if app.isJailbroken {
                Label("Telefon vypadá jako jailbreaknutý. Ochrana dat pak není spolehlivá.", systemImage: "exclamationmark.octagon.fill")
                    .foregroundStyle(.red).font(.subheadline)
            }
            Button {
                withAnimation { step = 1 }
            } label: {
                Text("Pokračovat").frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!DeviceIntegrity.hasPasscode)
        }
    }

    private var passwordStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nastav nouzové heslo. Použiješ ho, když Face ID nebude fungovat nebo se změní jeho nastavení – jinak by data nešla odemknout.")
                .foregroundStyle(.secondary)
            Text("Heslo nikde neukládáme. Když heslo zapomeneš a Face ID se změní, data nepůjde obnovit (jen ze zálohy).")
                .font(.footnote).foregroundStyle(.orange)
            SecureField("Nouzové heslo (aspoň 10 znaků)", text: $password)
                .textContentType(.newPassword)
                .textFieldStyle(.roundedBorder)
            SecureField("Heslo znovu", text: $password2)
                .textContentType(.newPassword)
                .textFieldStyle(.roundedBorder)
            if let hint = PasswordPolicy.hint(password), !password.isEmpty {
                Text(hint).font(.footnote).foregroundStyle(.secondary)
            }
            if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            Button {
                Task { await finish() }
            } label: {
                HStack {
                    if working { ProgressView().tint(.white) }
                    Text("Vytvořit šifrovaný trezor")
                }
                .frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(working || !PasswordPolicy.isAcceptable(password) || password != password2)
        }
    }

    private func feature(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title3).foregroundStyle(Theme.accent).frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func finish() async {
        working = true
        defer { working = false }
        do {
            try await app.completeOnboarding(recoveryPassword: password)
            password = ""; password2 = ""
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }
}

struct LockView: View {
    @EnvironmentObject var app: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showRecovery = false
    @State private var password = ""
    @State private var cameFromBackground = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "lock.fill").font(.system(size: 54, weight: .semibold)).foregroundStyle(Theme.accent)
            Text("Osobní agent je zamčený").font(.title2.bold())
            if app.isJailbroken {
                Label("Zařízení vypadá jako jailbreaknuté – data nemusí být v bezpečí.", systemImage: "exclamationmark.octagon.fill")
                    .font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
            }
            if let m = app.lockMessage {
                Text(m).font(.subheadline).foregroundStyle(.orange).multilineTextAlignment(.center)
            }
            Spacer()
            if showRecovery {
                VStack(spacing: 12) {
                    SecureField("Nouzové heslo", text: $password)
                        .textContentType(.password)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.go)
                        .onSubmit { submit() }
                    Button("Odemknout heslem") { submit() }
                        .buttonStyle(.borderedProminent)
                        .disabled(password.isEmpty || app.isUnlocking)
                }
            } else {
                Button {
                    Task { await app.unlockWithBiometrics() }
                } label: {
                    Label("Odemknout pomocí \(KeyManager.biometryDescription)", systemImage: "faceid")
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(app.isUnlocking)
            }
            Button(showRecovery ? "Použít Face ID" : "Použít nouzové heslo") {
                withAnimation { showRecovery.toggle() }
            }
            .font(.subheadline)
        }
        .padding(28)
        .task {
            // Face ID hned po zobrazení (jen když je aplikace v popředí)
            if !showRecovery && scenePhase == .active { await app.unlockWithBiometrics() }
        }
        .onChange(of: scenePhase) { _, p in
            // Jen po návratu z pozadí – ne po zavření dialogu Face ID (jinak by se zacyklil).
            if p == .background { cameFromBackground = true }
            if p == .active && cameFromBackground && !showRecovery {
                cameFromBackground = false
                Task { await app.unlockWithBiometrics() }
            }
        }
    }

    private func submit() {
        let p = password
        password = ""
        Task { await app.unlockWithRecovery(password: p) }
    }
}
