import SwiftUI
import UniformTypeIdentifiers
import AgentCore

/// Binární dokument pro export (záloha je už zašifrovaná).
struct BinaryDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct BackupView: View {
    @EnvironmentObject var app: AppModel
    @State private var password = ""
    @State private var password2 = ""
    @State private var exportDoc: BinaryDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var importData: Data?
    @State private var importPassword = ""
    @State private var payload: BackupPayload?
    @State private var working = false
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                SecureField("Heslo zálohy (aspoň 10 znaků)", text: $password).textContentType(.newPassword)
                SecureField("Heslo znovu", text: $password2).textContentType(.newPassword)
                if let h = PasswordPolicy.hint(password), !password.isEmpty { Text(h).font(.caption).foregroundStyle(.secondary) }
                Button {
                    Task { await export() }
                } label: {
                    HStack { if working { ProgressView() }; Text("Vytvořit šifrovanou zálohu") }
                }
                .disabled(working || !PasswordPolicy.isAcceptable(password) || password != password2)
            } header: { Text("Export") } footer: {
                Text("Záloha je vždy šifrovaná (Argon2id + AES-256-GCM). Bez hesla ji nikdo nepřečte – ani ty. Heslo si dobře zapamatuj. Soubor si ulož kam chceš (např. do Souborů nebo na počítač).")
            }

            Section {
                Button("Vybrat soubor zálohy…") { showImporter = true }.disabled(working)
                if importData != nil {
                    SecureField("Heslo zálohy", text: $importPassword)
                    Button("Odemknout zálohu") { Task { await openImport() } }.disabled(importPassword.isEmpty || working)
                }
                if let p = payload {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Záloha z \(CzechFormat.longDate(p.createdAt, calendar: app.calendar))").font(.subheadline.weight(.semibold))
                        Text(p.counts).font(.caption).foregroundStyle(.secondary)
                        Text("Obnovení NAHRADÍ všechna současná data v aplikaci.").font(.caption).foregroundStyle(.orange)
                    }
                    Button("Obnovit ze zálohy", role: .destructive) { restore(p) }
                }
            } header: { Text("Obnovení") }
        }
        .navigationTitle("Záloha")
        .fileExporter(isPresented: $showExporter, document: exportDoc, contentType: .data,
                      defaultFilename: "osobni-agent-zaloha-\(CzechFormat.machine(Date(), calendar: app.calendar).prefix(10)).oabak") { result in
            exportDoc = nil
            AppPaths.clearTemp()
            if case .success = result { message = "Záloha uložena." }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.data, .item]) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            importData = try? Data(contentsOf: url)
            payload = nil
            if importData == nil { message = "Soubor nelze přečíst." }
        }
        .alert("Záloha", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(message ?? "") }
    }

    private func export() async {
        guard let store = app.store else { return }
        working = true
        defer { working = false }
        let pw = password
        do {
            let data = try await Task.detached(priority: .userInitiated) { try BackupService.export(store: store, password: pw) }.value
            password = ""; password2 = ""
            exportDoc = BinaryDocument(data: data)
            showExporter = true
        } catch {
            message = "Záloha selhala: \(error)"
        }
    }

    private func openImport() async {
        guard let data = importData else { return }
        working = true
        defer { working = false }
        let pw = importPassword
        do {
            payload = try await Task.detached(priority: .userInitiated) { try BackupService.open(data, password: pw) }.value
            importPassword = ""
        } catch {
            message = (error as? CryptoError)?.description ?? "\(error)"
        }
    }

    private func restore(_ p: BackupPayload) {
        guard let store = app.store else { return }
        do {
            try BackupService.restore(p, into: store)
            payload = nil
            importData = nil
            app.models.reload()
            message = "Data obnovena ze zálohy."
            Task { await app.loadModels() }
        } catch {
            message = "Obnovení selhalo, data zůstala beze změny: \(error)"
        }
    }
}

struct BenchmarkView: View {
    @EnvironmentObject var app: AppModel
    @EnvironmentObject var ai: AIService
    @State private var running = false
    @State private var done = 0
    @State private var results: [BenchmarkCaseResult] = []
    @State private var report: BenchmarkReport?
    @State private var cancelled = false
    @State private var exportDoc: BinaryDocument?
    @State private var showExporter = false

    var body: some View {
        List {
            Section {
                Text("Spustí \(BenchmarkSuite.cases.count) českých testovacích vět (připomínky, úkoly, události, dotazy, bezpečnost) přímo na načteném modelu – bez pevných pravidel. Změří rychlost a správnost volání nástrojů. Test pracuje jen s testovacími větami, ne s tvými daty.")
                    .font(.subheadline).foregroundStyle(.secondary)
                if !ai.isLLMReady {
                    Label("Nejdřív nahraj a načti jazykový model.", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                }
                if running {
                    ProgressView(value: Double(done), total: Double(BenchmarkSuite.cases.count)) {
                        Text("Test \(done)/\(BenchmarkSuite.cases.count)")
                    }
                    Button("Přerušit", role: .destructive) { cancelled = true; CancelFlag.shared.value = true }
                } else {
                    Button("Spustit test") { Task { await run() } }.disabled(!ai.isLLMReady)
                }
            }
            if let r = report {
                Section("Výsledek") {
                    Text(r.summaryText).font(.callout.monospaced())
                    Button("Uložit výsledek (JSON)") {
                        exportDoc = BinaryDocument(data: r.jsonData())
                        showExporter = true
                    }
                }
            }
            if !results.isEmpty {
                Section("Jednotlivé testy") {
                    ForEach(results, id: \.id) { r in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: r.correctDecision && r.correctArgs ? "checkmark.circle.fill" : r.correctDecision ? "circle.lefthalf.filled" : "xmark.circle.fill")
                                    .foregroundStyle(r.correctDecision && r.correctArgs ? .green : r.correctDecision ? .orange : .red)
                                Text(r.input).font(.subheadline)
                            }
                            Text(r.output).font(.caption2.monospaced()).foregroundStyle(.secondary).lineLimit(3)
                            Text(String(format: "%.1f s · %.1f tok/s", r.seconds, r.tokensPerSecond)).font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Test modelu")
        .fileExporter(isPresented: $showExporter, document: exportDoc, contentType: .json, defaultFilename: "test-modelu.json") { _ in exportDoc = nil }
    }

    private func run() async {
        guard let model = ai.llm else { return }
        running = true
        cancelled = false
        results = []
        report = nil
        done = 0
        let runner = BenchmarkRunner(model: model, calendar: app.calendar, now: Date())
        let r = await runner.run(progress: { i, _, res in
            Task { @MainActor in
                done = i
                if let res { results.append(res) }
                app.noteActivity()
            }
        }, isCancelled: { [cancelledRef = CancelFlag.shared] in cancelledRef.value })
        CancelFlag.shared.value = false
        report = r
        running = false
        model.resetCache()
    }
}

/// Jednoduchý sdílený příznak přerušení (čtený z vlákna modelu).
final class CancelFlag: @unchecked Sendable {
    static let shared = CancelFlag()
    var value = false
}
