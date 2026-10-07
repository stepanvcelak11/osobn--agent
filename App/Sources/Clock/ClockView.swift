import SwiftUI
import AgentCore

/// Hodiny: stopky, minutky (odpočty) a budíky.
struct ClockView: View {
    @EnvironmentObject var app: AppModel
    @EnvironmentObject var clock: AppClockService
    @State private var newAlarmTime = CzechFormat.calendar().date(bySettingHour: 7, minute: 0, second: 0, of: Date())!
    @State private var newAlarmDays: Set<Int> = []
    @State private var newAlarmLabel = ""
    @State private var customMinutes = 10
    @State private var error: String?

    var body: some View {
        List {
            stopwatchSection
            timersSection
            alarmsSection
            if !clock.usesAlarmKit {
                Section {
                    Label("Na tvé verzi iOS budíky fungují jako notifikace a v tichém režimu nezazvoní. Od iOS 26 se použijí skutečné budíky.", systemImage: "info.circle")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Hodiny")
        .alert("Hodiny", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
        .id(clock.version)
    }

    // MARK: Stopky

    private var stopwatchSection: some View {
        Section("Stopky") {
            TimelineView(.periodic(from: .now, by: 0.1)) { ctx in
                let st = clock.stopwatchState
                Text(CzechDuration.clock(st.elapsed(at: ctx.date), tenths: true))
                    .font(.system(size: 52, weight: .light, design: .rounded).monospacedDigit())
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Stopky \(CzechDuration.format(st.elapsed(at: ctx.date)))")
            }
            HStack(spacing: 12) {
                let running = clock.stopwatchState.isRunning
                Button(running ? "Mezičas" : "Vynulovat") {
                    _ = clock.stopwatch(running ? .lap : .reset)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                Button(running ? "Zastavit" : "Spustit") {
                    _ = clock.stopwatch(running ? .stop : .start)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                .buttonStyle(.borderedProminent)
                .tint(running ? .red : .green)
                .frame(maxWidth: .infinity)
            }
            ForEach(Array(clock.stopwatchState.laps.enumerated().reversed()), id: \.offset) { i, lap in
                HStack {
                    Text("Mezičas \(i + 1)").foregroundStyle(.secondary)
                    Spacer()
                    Text(CzechDuration.clock(lap, tenths: true)).monospacedDigit()
                }
            }
        }
    }

    // MARK: Minutky

    private var timersSection: some View {
        Section("Minutka") {
            let timers = clock.activeAlarms().filter { $0.kind == .timer }
            ForEach(timers) { t in
                HStack {
                    VStack(alignment: .leading) {
                        Text(t.label)
                        if let f = t.fireDate {
                            Text(timerInterval: Date()...max(Date(), f), countsDown: true)
                                .font(.title3.monospacedDigit())
                        }
                    }
                    Spacer()
                    Button(role: .destructive) { try? clock.cancel(id: t.id) } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                        .accessibilityLabel("Zrušit odpočet")
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach([1, 3, 5, 10, 15, 30, 60], id: \.self) { m in
                        Button(m == 60 ? "1 h" : "\(m) min") { startTimer(minutes: m) }
                            .buttonStyle(.bordered)
                    }
                }
            }
            Stepper(value: $customMinutes, in: 1...600) {
                HStack {
                    Text("\(customMinutes) min")
                    Spacer()
                    Button("Spustit") { startTimer(minutes: customMinutes) }.buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func startTimer(minutes: Int) {
        Task {
            do { _ = try await clock.startTimer(label: "Minutka", duration: TimeInterval(minutes * 60)) }
            catch { self.error = "\(error)" }
        }
    }

    // MARK: Budíky

    private var alarmsSection: some View {
        Section {
            let alarms = clock.activeAlarms().filter { $0.kind == .alarm }
            if alarms.isEmpty { Text("Žádné budíky").foregroundStyle(.secondary) }
            ForEach(alarms) { a in
                HStack {
                    VStack(alignment: .leading) {
                        Text(a.hour.map { CzechFormat.time(hour: $0, minute: a.minute ?? 0) } ?? "").font(.title2.monospacedDigit())
                        Text((a.label == "Budík" ? "" : a.label + " · ") + a.describe(now: Date(), calendar: app.calendar))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .swipeActions {
                    Button(role: .destructive) { try? clock.cancel(id: a.id) } label: { Label("Zrušit", systemImage: "trash") }
                }
            }
            DatePicker("Nový budík", selection: $newAlarmTime, displayedComponents: .hourAndMinute)
            HStack(spacing: 4) {
                ForEach(1...7, id: \.self) { d in
                    let on = newAlarmDays.contains(d)
                    Button(CzechFormat.weekdayShort[d - 1]) {
                        if on { newAlarmDays.remove(d) } else { newAlarmDays.insert(d) }
                    }
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .background(on ? Theme.accent : Color(.tertiarySystemFill), in: Circle())
                    .foregroundStyle(on ? .white : .primary)
                    .buttonStyle(.plain)
                    .accessibilityLabel(CzechFormat.weekdayNominative[d - 1])
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            TextField("Popisek (nepovinný)", text: $newAlarmLabel)
            Button("Přidat budík") { addAlarm() }
        } header: { Text("Budíky") } footer: {
            Text("Bez vybraných dnů zazvoní jednou (dnes, nebo zítra, pokud už čas byl). Budík můžeš nastavit i hlasem: „vzbuď mě zítra v 6:30“.")
        }
    }

    private func addAlarm() {
        let cal = app.calendar
        let h = cal.component(.hour, from: newAlarmTime), m = cal.component(.minute, from: newAlarmTime)
        var date = cal.date(bySettingHour: h, minute: m, second: 0, of: Date())!
        if date <= Date() { date = cal.date(byAdding: .day, value: 1, to: date)! }
        let label = newAlarmLabel.trimmingCharacters(in: .whitespaces).isEmpty ? "Budík" : newAlarmLabel
        Task {
            do {
                _ = try await clock.scheduleAlarm(label: label, date: date, weekdays: Array(newAlarmDays).sorted(), hour: h, minute: m)
                newAlarmLabel = ""
                newAlarmDays = []
            } catch { self.error = "\(error)" }
        }
    }
}
