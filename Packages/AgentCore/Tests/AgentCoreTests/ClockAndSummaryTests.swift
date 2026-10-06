import XCTest
@testable import AgentCore

final class FakeClockService: ClockService {
    var alarms: [ClockAlarm] = []
    var cancelled: [String] = []
    var sw = StopwatchState()
    var now: Date = TS.now
    func scheduleAlarm(label: String, date: Date, weekdays: [Int], hour: Int, minute: Int) async throws -> ClockAlarm {
        let a = ClockAlarm(kind: .alarm, label: label, fireDate: date, weekdays: weekdays, hour: hour, minute: minute)
        alarms.append(a); return a
    }
    func startTimer(label: String, duration: TimeInterval) async throws -> ClockAlarm {
        let a = ClockAlarm(kind: .timer, label: label, fireDate: now.addingTimeInterval(duration), duration: duration)
        alarms.append(a); return a
    }
    func cancel(id: String) throws { cancelled.append(id); alarms.removeAll { $0.id == id } }
    func activeAlarms() -> [ClockAlarm] { alarms }
    func stopwatch(_ action: StopwatchAction) -> StopwatchState { sw.apply(action, now: now); return sw }
}

final class ClockTests: XCTestCase {
    func testDurations() {
        XCTAssertEqual(CzechDuration.parse("10 minut"), 600)
        XCTAssertEqual(CzechDuration.parse("hodinu a půl"), 5400)
        XCTAssertEqual(CzechDuration.parse("1,5 hodiny"), 5400)
        XCTAssertEqual(CzechDuration.parse("90 sekund"), 90)
        XCTAssertEqual(CzechDuration.parse("půl hodiny"), 1800)
        XCTAssertEqual(CzechDuration.parse("na 5 min"), 300)
        XCTAssertEqual(CzechDuration.parse("deset minut"), 600)
        XCTAssertEqual(CzechDuration.parse("2 hodiny 15 minut"), 8100)
        XCTAssertNil(CzechDuration.parse("schůzka s Petrem"))
        XCTAssertEqual(CzechDuration.format(5400), "1 h 30 min")
        XCTAssertEqual(CzechDuration.clock(3725), "1:02:05")
        XCTAssertEqual(CzechDuration.clock(65.4, tenths: true), "01:05,4")
    }

    func testAlarmModeTimes() {
        let p = CzechTimeParser(calendar: TS.cal, now: TS.now, alarmMode: true)
        XCTAssertEqual(TS.fmt(p.parse("vzbuď mě v 6")?.date), "2026-10-07 06:00")
        XCTAssertEqual(TS.fmt(p.parse("budík na 6:30")?.date), "2026-10-07 06:30")
        XCTAssertEqual(TS.fmt(p.parse("zítra v půl sedmé")?.date), "2026-10-07 06:30")
        XCTAssertEqual(TS.fmt(p.parse("v 11")?.date), "2026-10-06 11:00")
        XCTAssertEqual(p.parse("každý pracovní den v 6:15")?.recurrence?.weekdays, [1, 2, 3, 4, 5])
        // Běžný režim „v 6“ = 18:00
        XCTAssertEqual(TS.fmt(TS.parser().parse("v 6")?.date), "2026-10-06 18:00")
    }

    func testClockRules() {
        let r = RuleRouter(calendar: TS.cal, now: TS.now)
        guard case .tool(let t)? = r.route("Minutka 10 minut na vajíčka") else { return XCTFail() }
        XCTAssertEqual(t.name, "set_timer"); XCTAssertEqual(t.args["label"]?.stringValue, "Vajíčka")
        guard case .tool(let t2)? = r.route("nastav časovač na 5 minut") else { return XCTFail() }
        XCTAssertEqual(t2.name, "set_timer"); XCTAssertNil(t2.args["label"])
        guard case .tool(let a)? = r.route("vzbuď mě zítra v půl sedmé") else { return XCTFail() }
        XCTAssertEqual(a.name, "set_alarm")
        guard case .tool(let a2)? = r.route("nastav budík na 7 na trénink") else { return XCTFail() }
        XCTAssertEqual(a2.args["label"]?.stringValue, "Trénink")
        guard case .tool(let s)? = r.route("spusť stopky") else { return XCTFail() }
        XCTAssertEqual(s.args["action"]?.stringValue, "start")
        guard case .tool(let s2)? = r.route("zastav stopky") else { return XCTFail() }
        XCTAssertEqual(s2.args["action"]?.stringValue, "stop")
        guard case .tool(let c)? = r.route("zruš budík") else { return XCTFail() }
        XCTAssertEqual(c.name, "cancel_alarm")
        guard case .tool(let l)? = r.route("jaké mám budíky") else { return XCTFail() }
        XCTAssertEqual(l.name, "list_alarms")
        guard case .clarify? = r.route("nastav budík") else { return XCTFail() }
        // Připomínka zůstává připomínkou
        guard case .tool(let rem)? = r.route("za 10 minut mi připomeň vypnout troubu") else { return XCTFail() }
        XCTAssertEqual(rem.name, "create_reminder")
    }

    func makeAgent() throws -> (AgentEngine, FakeClockService) {
        let agent = AgentEngine(store: try DataStore.inMemory(), model: nil, calendar: TS.cal, clock: { TS.now })
        let fake = FakeClockService()
        agent.executor.clockService = fake
        return (agent, fake)
    }

    func testAlarmEndToEndWithUndo() async throws {
        let (agent, fake) = try makeAgent()
        let r = await agent.handle("vzbuď mě zítra v 6:30")
        XCTAssertEqual(r.actions.first?.status, .applied)
        XCTAssertEqual(r.actions.first?.summary, "Budík zítra v 6:30")
        XCTAssertEqual(fake.alarms.count, 1)
        let u = await agent.handle("vrať to")
        XCTAssertEqual(u.actions.first?.status, .undone)
        XCTAssertEqual(fake.alarms.count, 0)
    }

    func testRecurringAlarmAndClarify() async throws {
        let (agent, fake) = try makeAgent()
        let q = await agent.handle("nastav budík")
        XCTAssertTrue(q.isQuestion)
        _ = await agent.handle("každý pracovní den v 6:15")
        XCTAssertEqual(fake.alarms.first?.weekdays, [1, 2, 3, 4, 5])
        XCTAssertEqual(fake.alarms.first?.hour, 6)
    }

    func testCancelAlarmNeedsConfirmationTimerDoesNot() async throws {
        let (agent, fake) = try makeAgent()
        _ = await agent.handle("vzbuď mě zítra v 7")
        _ = await agent.handle("minutka 5 minut na čaj")
        let c = await agent.handle("zruš budík")
        XCTAssertEqual(c.actions.first?.status, .pending)
        XCTAssertEqual(fake.alarms.count, 2, "budík se ruší až po potvrzení")
        try agent.executor.confirm(actionId: c.actions[0].id)
        XCTAssertEqual(fake.alarms.map(\.kind), [.timer])
        let t = await agent.handle("zruš minutku")
        XCTAssertEqual(t.actions.first?.status, .applied)
        XCTAssertTrue(fake.alarms.isEmpty)
    }

    func testStopwatch() async throws {
        let (agent, fake) = try makeAgent()
        _ = await agent.handle("spusť stopky")
        fake.now = TS.now.addingTimeInterval(65.4)
        let r = await agent.handle("zastav stopky")
        XCTAssertEqual(r.text, "Stopky zastaveny na 01:05,4.")
    }

    func testTimerWithoutClockService() async throws {
        let agent = AgentEngine(store: try DataStore.inMemory(), model: nil, calendar: TS.cal, clock: { TS.now })
        let r = await agent.handle("minutka 10 minut")
        XCTAssertTrue(r.isQuestion)
        XCTAssertTrue(r.text.contains("nejsou dostupné"))
    }
}

final class SummaryAndLinksTests: XCTestCase {
    func testSummarizerMapReduce() async throws {
        // Malý kontext → víc částí
        final class SmallModel: LanguageModel, @unchecked Sendable {
            var prompts: [String] = []
            let displayName = "small"; let template: ChatTemplate = .chatml; let contextLength = 1600
            func generate(prompt: String, options: GenerationOptions, onToken: @escaping @Sendable (String) -> Bool) async throws -> (text: String, stats: GenerationStats) {
                prompts.append(prompt)
                if options.grammar == TranscriptSummarizer.finalGrammar {
                    return (#"{"title":"Fotosyntéza","summary":"Přednáška o fotosyntéze.","points":["Světlo","Chlorofyl"],"tasks":["Přečíst kapitolu 3"]}"#, GenerationStats())
                }
                return (#"{"type":"answer","text":"- dílčí bod"}"#, GenerationStats())
            }
            func countTokens(_ text: String) -> Int { text.count / 4 }
        }
        let m = SmallModel()
        let s = TranscriptSummarizer(model: m)
        let transcript = Array(repeating: "Rostliny přeměňují světlo na energii pomocí chlorofylu", count: 400).joined(separator: ". ")
        XCTAssertGreaterThan(s.split(transcript).count, 3)
        let r = try await s.summarize(transcript: transcript, kind: .lecture)
        XCTAssertEqual(r.title, "Fotosyntéza")
        XCTAssertEqual(r.tasks, ["Přečíst kapitolu 3"])
        XCTAssertGreaterThan(m.prompts.count, 3)
        XCTAssertTrue(m.prompts.allSatisfy { m.countTokens($0) < m.contextLength })
        let body = r.noteBody(transcript: "ahoj", recordedAt: TS.now, duration: 3600, calendar: TS.cal)
        XCTAssertTrue(body.contains("HLAVNÍ BODY\n• Světlo"))
        XCTAssertTrue(body.contains("PŘEPIS\nahoj"))
    }

    func testProposeCreatesPendingTask() async throws {
        let agent = AgentEngine(store: try DataStore.inMemory(), model: nil, calendar: TS.cal, clock: { TS.now })
        let out = try await agent.executor.propose(ToolCall("create_task", ["title": "Přečíst kapitolu 3"]), source: "shrnutí")
        XCTAssertEqual(out.action?.status, .pending)
        XCTAssertEqual(try agent.store.tasks().count, 0)
        try agent.executor.confirm(actionId: out.action!.id)
        XCTAssertEqual(try agent.store.tasks().count, 1)
        // Další akce už nejsou návrhy
        let n = try await agent.executor.execute(ToolCall("create_note", ["text": "x"]), source: "test")
        XCTAssertEqual(n.action?.status, .applied)
    }

    func testEntityHooksAndLinks() throws {
        let s = try DataStore.inMemory()
        var changed: [EntityRef] = []
        s.onEntityChange = { changed.append($0) }
        let e = Event(title: "A", startAt: TS.now)
        try s.insert(e)
        try s.softDelete(EntityRef(kind: .event, id: e.id))
        XCTAssertEqual(changed.count, 2)
        let ref = EntityRef(kind: .event, id: e.id)
        try s.setExternalId("EK-1", for: ref, system: "ek")
        XCTAssertEqual(try s.externalId(ref, system: "ek"), "EK-1")
        XCTAssertEqual(try s.externalIds(system: "ek"), ["EK-1"])
        try s.setExternalId(nil, for: ref, system: "ek")
        XCTAssertNil(try s.externalId(ref, system: "ek"))
    }

    func testExternalEventsInAgenda() throws {
        let s = try DataStore.inMemory()
        let ext: @Sendable (Date, Date) -> [ExternalAgendaItem] = { from, to in
            let d = TS.date(2026, 10, 6, 16, 0)
            return d >= from && d < to ? [ExternalAgendaItem(id: "x", title: "Zubař", start: d, end: nil, allDay: false, location: nil, source: "Kalendář Apple")] : []
        }
        let b = OverviewBuilder(store: s, calendar: TS.cal, now: TS.now, external: ext)
        let text = try b.agendaText(.today, refs: RefRegistry())
        XCTAssertTrue(text.contains("Zubař (Kalendář Apple)"), text)
        XCTAssertEqual(try b.overview().next?.title, "Zubař")
    }
}
