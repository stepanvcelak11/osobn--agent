import SwiftUI
import UniformTypeIdentifiers
import RealmCore

struct ModelsView: View {
    @EnvironmentObject var app: AppModel
    @EnvironmentObject var models: ModelManager
    @EnvironmentObject var ai: AIService
    @State private var importKind: ModelKind = .llm
    @State private var expectedHash = ""
    @State private var showImporter = false
    @State private var pending: PendingImport?
    @State private var confirmedHash = false
    @State private var message: String?
    @State private var working = false
    @State private var contextLength = 4096

    var body: some View {
        List {
            ForEach(ModelKind.allCases, id: \.self) { kind in
                Section(kind.czechName) {
                    let list = models.installed.filter { $0.kind == kind }
                    if list.isEmpty { Text("Žádný model").foregroundStyle(.secondary) }
                    ForEach(list) { m in modelRow(m) }
                    stateRow(kind)
                }
            }

            Section {
                Picker("Typ modelu", selection: $importKind) {
                    ForEach(ModelKind.allCases, id: \.self) { Text($0.czechName).tag($0) }
                }
                TextField("Očekávaný SHA-256 (doporučeno)", text: $expectedHash, axis: .vertical)
                    .font(.system(.footnote, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    showImporter = true
                } label: {
                    Label("Vybrat soubor modelu…", systemImage: "square.and.arrow.down")
                }
                .disabled(working)
                if let p = models.importProgress {
                    VStack(alignment: .leading) {
                        Text(models.importStatus).font(.caption)
                        ProgressView(value: p)
                    }
                }
            } header: { Text("Vlastní model (pro pokročilé)") } footer: {
                Text("Vypravěč se stahuje automaticky. Sem sahej jen pokud chceš jiný model: soubor .gguf si ulož do Souborů a vyber ho zde. Hra ověří kontrolní součet SHA-256; soubor s nesouhlasným součtem odmítne.")
            }

            Section("Doporučené modely") {
                ForEach(ModelCatalog.models) { c in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(c.name).font(.subheadline.weight(.semibold))
                            if c.recommended { Text("doporučeno").font(.caption2).padding(.horizontal, 6).padding(.vertical, 2).background(Theme.ember.opacity(0.25), in: Capsule()) }
                        }
                        Text("\(c.kind.czechName) · ~\(c.approxSizeMB) MB").font(.caption).foregroundStyle(.secondary)
                        Text("Soubor: \(c.fileName)").font(.caption2.monospaced()).foregroundStyle(.secondary)
                        Text("Zdroj: \(c.source)").font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
                        if let s = c.sha1 { Text("SHA-1: \(s)").font(.caption2.monospaced()).foregroundStyle(.secondary).textSelection(.enabled) }
                        Text(c.note).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Picker("Délka kontextu", selection: $contextLength) {
                    Text("3072 tokenů (méně paměti)").tag(3072)
                    Text("4096 tokenů (doporučeno)").tag(4096)
                    Text("6144 tokenů (delší paměť příběhu)").tag(6144)
                }
                Button("Znovu načíst modely") { Task { await reloadModels() } }
            } header: { Text("Výkon") } footer: {
                Text("iPhone 14 Pro má 6 GB RAM. Pro Gemma 3 4B (Q4) doporučujeme kontext 4096 – vypravěč si pamatuje posledních pár tahů a kroniku. Kdyby aplikace padala kvůli paměti, zvol 3072.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg0)
        .navigationTitle("Modely")
        .onAppear { contextLength = ai.contextLength }
        .onChange(of: contextLength) { _, v in ai.contextLength = v }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.data, .item], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { await runImport(url) }
        }
        .sheet(item: $pending) { p in confirmSheet(p) }
        .alert("Modely", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(message ?? "") }
    }

    private func modelRow(_ m: InstalledModel) -> some View {
        let isActive = models.active(m.kind)?.id == m.id
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: isActive ? "checkmark.circle.fill" : "circle").foregroundStyle(isActive ? .green : .secondary)
                Text(m.displayName).font(.subheadline.weight(.semibold))
            }
            Text("\(m.sizeText) · ověřeno: \(m.verifiedBy)").font(.caption).foregroundStyle(.secondary)
            Text("SHA-256: \(m.sha256)").font(.caption2.monospaced()).foregroundStyle(.secondary).lineLimit(2).textSelection(.enabled)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            models.activate(m)
            Task { await reloadModels() }
        }
        .swipeActions {
            Button(role: .destructive) {
                models.delete(m)
                Task { await reloadModels() }
            } label: { Label("Smazat", systemImage: "trash") }
            Button {
                Task {
                    let ok = await models.reverify(m)
                    message = ok ? "Soubor je v pořádku – kontrolní součet sedí." : "POZOR: kontrolní součet nesedí! Model smaž a nahraj znovu."
                }
            } label: { Label("Ověřit", systemImage: "checkmark.shield") }.tint(.blue)
        }
    }

    @ViewBuilder private func stateRow(_ kind: ModelKind) -> some View {
        let state: AIService.State = kind == .llm ? ai.llmState : ai.speechState
        switch state {
        case .loading(let n): HStack { ProgressView(); Text("Načítám \(n)…").font(.caption) }
        case .failed(let e): Text(e).font(.caption).foregroundStyle(.red)
        case .ready(let n): Text("Načteno: \(n)").font(.caption).foregroundStyle(.green)
        case .none: if kind == .speech && models.active(.speech) != nil { Text("Načte se při prvním diktování").font(.caption).foregroundStyle(.secondary) }
        }
    }

    private func runImport(_ url: URL) async {
        working = true
        defer { working = false }
        do {
            switch try await models.importModel(from: url, kind: importKind, expectedHash: expectedHash.isEmpty ? nil : expectedHash) {
            case .installed(let m):
                expectedHash = ""
                message = "Model „\(m.displayName)“ je ověřený (\(m.verifiedBy)) a připravený."
                await reloadModels()
            case .needsConfirmation(let p):
                confirmedHash = false
                pending = p
            }
        } catch {
            message = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }

    /// Uvolní starý model (kvůli paměti) a načte aktivní.
    private func reloadModels() async {
        await ai.loadLLM(nil)
        await app.loadModels()
    }

    private func confirmSheet(_ p: PendingImport) -> some View {
        NavigationStack {
            Form {
                Section {
                    Label("Pro tento soubor není známý kontrolní součet.", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text("Porovnej SHA-256 níže se součtem na stránce, odkud model pochází (Hugging Face → soubor → „SHA256“). Pokud se liší, soubor může být podvržený – nepoužívej ho.")
                        .font(.subheadline)
                }
                Section("Soubor") {
                    LabeledContent("Název", value: p.fileName)
                    LabeledContent("Velikost", value: ByteCountFormatter.string(fromByteCount: p.digest.size, countStyle: .file))
                    VStack(alignment: .leading) {
                        Text("SHA-256").font(.caption).foregroundStyle(.secondary)
                        Text(p.digest.sha256).font(.footnote.monospaced()).textSelection(.enabled)
                    }
                }
                Section {
                    Toggle("Součet souhlasí se zdrojem", isOn: $confirmedHash)
                }
            }
            .navigationTitle("Ověření modelu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Odmítnout") { models.discard(p); pending = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Použít") {
                        do {
                            let m = try models.confirm(p)
                            pending = nil
                            message = "Model „\(m.displayName)“ přidán."
                            Task { await reloadModels() }
                        } catch { message = "\(error)" }
                    }
                    .disabled(!confirmedHash)
                }
            }
        }
        .interactiveDismissDisabled()
    }
}
