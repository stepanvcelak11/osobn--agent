import SwiftUI
import AgentCore

struct ChatView: View {
    @EnvironmentObject var app: AppModel
    @EnvironmentObject var chat: ChatController
    @EnvironmentObject var ai: AIService
    @EnvironmentObject var speaker: Speaker
    @State private var text = ""
    @FocusState private var focused: Bool
    @State private var confirmClear = false

    private let suggestions = [
        "Co mám dnes?",
        "Zítra v 8 mi připomeň zavolat doktorovi",
        "Poznamenej si: ",
        "Jaké mám úkoly?",
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if chat.messages.isEmpty && !chat.busy { emptyState }
                            ForEach(chat.messages) { m in
                                MessageRow(message: m, action: m.actionId.flatMap { chat.actions[$0] })
                                    .id(m.id)
                            }
                            if chat.busy {
                                if !chat.streaming.isEmpty {
                                    Bubble(text: chat.streaming, isUser: false)
                                } else {
                                    HStack { ThinkingIndicator(text: chat.progressText ?? "Přemýšlím…"); Spacer() }
                                        .padding(.horizontal, 4)
                                }
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: chat.messages.count) { _, _ in withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
                    .onChange(of: chat.streaming) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
                    .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                inputBar
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { modelBadge }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if speaker.isSpeaking { Button("Zastavit čtení", systemImage: "speaker.slash") { speaker.stop() } }
                        Button("Smazat historii chatu", systemImage: "trash", role: .destructive) { confirmClear = true }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .confirmationDialog("Smazat celou historii chatu? Vytvořené položky zůstanou.", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Smazat historii", role: .destructive) {
                    try? app.store?.clearConversation()
                    app.ai.llm?.resetCache()
                    chat.reload(app.store)
                }
            }
        }
        .onAppear { chat.reload(app.store) }
        .onChange(of: app.dataVersion) { _, _ in if !chat.busy { chat.reload(app.store) } }
        .onReceive(NotificationCenter.default.publisher(for: .focusChatInput)) { _ in focused = true }
    }

    private var modelBadge: some View {
        Group {
            switch ai.llmState {
            case .ready: Label("Model", systemImage: "cpu").labelStyle(.iconOnly).foregroundStyle(.green)
            case .loading: ProgressView().controlSize(.small)
            case .failed: Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
            case .none: Image(systemName: "cpu").foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel(ai.isLLMReady ? "Jazykový model načten" : "Jazykový model není načten")
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Napiš nebo podrž mikrofon a řekni, co potřebuješ.")
                .foregroundStyle(.secondary)
            if !ai.isLLMReady {
                Label("Jazykový model není načtený – fungují jen základní příkazy. Nahraj model v Nastavení → Modely.", systemImage: "info.circle")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(suggestions, id: \.self) { s in
                Button {
                    text = s
                    focused = true
                } label: {
                    Text(s).font(.subheadline)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 20)
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Napiš zprávu…", text: $text, axis: .vertical)
                .lineLimit(1...5)
                .focused($focused)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .submitLabel(.send)
                .onSubmit(sendText)
            Button(action: sendText) {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 34))
            }
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || chat.busy)
            .accessibilityLabel("Odeslat")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.bar)
    }

    private func sendText() {
        let t = text
        text = ""
        Task { _ = await chat.send(t, app: app) }
    }
}

struct Bubble: View {
    var text: String
    var isUser: Bool
    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            Text(text)
                .textSelection(.enabled)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .foregroundStyle(isUser ? Color.white : Color.primary)
                .background(isUser ? Theme.accent : Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            if !isUser { Spacer(minLength: 40) }
        }
    }
}

struct MessageRow: View {
    var message: ChatMessage
    var action: ActionRecord?
    var body: some View {
        switch message.role {
        case .user: Bubble(text: message.text, isUser: true)
        case .assistant, .system: Bubble(text: message.text, isUser: false)
        case .action:
            if let action { ActionCardView(action: action) } else { Bubble(text: message.text, isUser: false) }
        }
    }
}
