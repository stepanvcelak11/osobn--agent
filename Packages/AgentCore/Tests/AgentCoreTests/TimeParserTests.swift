import XCTest
@testable import AgentCore

final class TimeParserTests: XCTestCase {
    // „Teď“ = úterý 6. 10. 2026 10:00

    func check(_ text: String, _ expected: String, file: StaticString = #filePath, line: UInt = #line) {
        let r = TS.parser().parse(text)
        XCTAssertEqual(TS.fmt(r?.date), expected, "„\(text)“", file: file, line: line)
    }

    func testRelativeDays() {
        check("zítra v 8 mi připomeň zavolat doktorovi", "2026-10-07 08:00")
        check("Zitra v 8:30", "2026-10-07 08:30")
        check("pozítří ve 14 hodin", "2026-10-08 14:00")
        check("dnes ve 20:15", "2026-10-06 20:15")
        check("dneska večer", "2026-10-06 19:00")
        check("zítra ráno", "2026-10-07 08:00")
        check("zítra odpoledne", "2026-10-07 15:00")
    }

    func testLooseHours() {
        // „ve tři“ = 15:00
        check("ve tři zavolat mámě", "2026-10-06 15:00")
        check("zítra ve 3", "2026-10-07 15:00")
        // „v 8“ dnes (8:00 už bylo) → 20:00
        check("v 8 vynést koš", "2026-10-06 20:00")
        // „v 11“ ještě nebylo → 11:00
        check("v 11 porada", "2026-10-06 11:00")
        check("večer v 9", "2026-10-06 21:00")
        check("v 7 ráno", "2026-10-07 07:00")
        check("v osm večer", "2026-10-06 20:00")
        check("v devět ráno", "2026-10-07 09:00")
    }

    func testHalfAndQuarter() {
        check("zítra o půl osmé", "2026-10-07 07:30")
        check("zítra ve čtvrt na devět", "2026-10-07 08:15")
        check("zítra ve tři čtvrtě na devět", "2026-10-07 08:45")
        check("o půl třetí", "2026-10-06 14:30")
        check("zítra v poledne", "2026-10-07 12:00")
    }

    func testOffsets() {
        check("za 2 hodiny", "2026-10-06 12:00")
        check("za hodinu", "2026-10-06 11:00")
        check("za půl hodiny", "2026-10-06 10:30")
        check("za 15 minut", "2026-10-06 10:15")
        check("za dvacet minut", "2026-10-06 10:20")
        check("za 3 dny v 9", "2026-10-09 09:00")
        check("za týden", "2026-10-13 09:00")
    }

    func testWeekdays() {
        check("v pondělí v 9", "2026-10-12 09:00")
        check("ve středu", "2026-10-07 09:00")
        check("ve čtvrtek ve 14:30", "2026-10-08 14:30")
        // dnes je úterý → „v úterý“ = příští týden
        check("v úterý", "2026-10-13 09:00")
        check("příští pátek", "2026-10-16 09:00")
        check("příští týden", "2026-10-12 09:00")
        check("o víkendu", "2026-10-10 09:00")
        check("v sobotu večer", "2026-10-10 19:00")
    }

    func testAbsoluteDates() {
        check("15. 10. v 10:00", "2026-10-15 10:00")
        check("15.10.2026 ve 13:45", "2026-10-15 13:45")
        check("1. listopadu", "2026-11-01 09:00")
        check("3. 1.", "2027-01-03 09:00") // minulé datum → příští rok
        check("2026-12-24 18:00", "2026-12-24 18:00")
        check("24. prosince v 18", "2026-12-24 18:00")
    }

    func testWithoutDiacritics() {
        check("pripomen mi zitra v 8 zavolat doktorovi", "2026-10-07 08:00")
        check("ve ctvrtek o pul osme", "2026-10-08 07:30")
    }

    func testNoTime() {
        XCTAssertNil(TS.parser().parse("koupit mléko"))
        XCTAssertNil(TS.parser().parse("zavolat 2 lidem"))
        let r = TS.parser().parse("zítra")!
        XCTAssertTrue(r.hasDate)
        XCTAssertFalse(r.hasTime)
    }

    func testRecurrence() {
        let p = TS.parser()
        var r = p.parse("každé pondělí a čtvrtek v 7 cvičit")!
        XCTAssertEqual(r.recurrence?.frequency, .weekly)
        XCTAssertEqual(r.recurrence?.weekdays, [1, 4])
        XCTAssertEqual(r.recurrence?.hour, 7)
        XCTAssertEqual(TS.fmt(r.date), "2026-10-08 07:00")
        XCTAssertEqual(r.recurrence?.czechDescription, "každé pondělí a čtvrtek v 7:00")

        r = p.parse("každý den v 8:30")!
        XCTAssertEqual(r.recurrence?.frequency, .daily)
        XCTAssertEqual(TS.fmt(r.date), "2026-10-07 08:30")

        r = p.parse("denně ve 20")!
        XCTAssertEqual(TS.fmt(r.date), "2026-10-06 20:00")

        r = p.parse("každý pracovní den v 6:45")!
        XCTAssertEqual(r.recurrence?.weekdays, [1, 2, 3, 4, 5])
        XCTAssertEqual(r.recurrence?.czechDescription, "každý pracovní den v 6:45")

        r = p.parse("každou středu ve 3")!
        XCTAssertEqual(r.recurrence?.weekdays, [3])
        XCTAssertEqual(TS.fmt(r.date), "2026-10-07 15:00")

        r = p.parse("každé ráno")!
        XCTAssertEqual(r.recurrence?.frequency, .daily)
        XCTAssertEqual(TS.fmt(r.date), "2026-10-07 08:00")

        r = p.parse("o víkendech v 9")!
        XCTAssertEqual(r.recurrence?.weekdays, [6, 7])

        r = p.parse("každého 15. v 10")!
        XCTAssertEqual(r.recurrence?.frequency, .monthly)
        XCTAssertEqual(r.recurrence?.monthDay, 15)
        XCTAssertEqual(TS.fmt(r.date), "2026-10-15 10:00")

        r = p.parse("obden v 8")!
        XCTAssertEqual(r.recurrence?.interval, 2)

        r = p.parse("v pondělky a čtvrtky v 18")!
        XCTAssertEqual(r.recurrence?.weekdays, [1, 4])
        XCTAssertEqual(TS.fmt(r.date), "2026-10-08 18:00")

        r = p.parse("každý rok 24. 12. v 18")!
        XCTAssertEqual(r.recurrence?.frequency, .yearly)
        XCTAssertEqual(TS.fmt(r.date), "2026-12-24 18:00")
    }

    func testRemainder() {
        let p = TS.parser()
        let text = "zítra v 8 mi připomeň zavolat doktorovi"
        let r = p.parse(text)!
        XCTAssertEqual(p.remainder(of: text, removing: r.ranges), "mi připomeň zavolat doktorovi")
        let t2 = "Připomeň mi každé pondělí a čtvrtek v 7:00 cvičit"
        let r2 = p.parse(t2)!
        XCTAssertEqual(p.remainder(of: t2, removing: r2.ranges), "Připomeň mi cvičit")
    }

    func testRecurrenceMonthEnd() {
        let rec = Recurrence(frequency: .monthly, monthDay: 31, hour: 9, minute: 0)
        let occ = rec.occurrences(from: TS.date(2026, 10, 1), to: TS.date(2027, 1, 1), anchor: TS.date(2026, 10, 31, 9), calendar: TS.cal)
        XCTAssertEqual(occ.map(TS.fmt), ["2026-10-31 09:00", "2026-11-30 09:00", "2026-12-31 09:00"])
    }

    func testDSTTransition() {
        // 25. 10. 2026 končí letní čas – denní připomínka zůstává v 8:00 místního času.
        let rec = Recurrence(frequency: .daily, hour: 8, minute: 0)
        let occ = rec.occurrences(from: TS.date(2026, 10, 24), to: TS.date(2026, 10, 27), anchor: TS.date(2026, 10, 1, 8), calendar: TS.cal)
        XCTAssertEqual(occ.map(TS.fmt), ["2026-10-24 08:00", "2026-10-25 08:00", "2026-10-26 08:00"])
    }

    func testFormatting() {
        let cal = TS.cal
        XCTAssertEqual(CzechFormat.relativeDateTime(TS.date(2026, 10, 7, 8, 0), now: TS.now, calendar: cal), "zítra v 8:00")
        XCTAssertEqual(CzechFormat.relativeDateTime(TS.date(2026, 10, 7, 14, 0), now: TS.now, calendar: cal), "zítra ve 14:00")
        XCTAssertEqual(CzechFormat.relativeDateTime(TS.date(2026, 10, 9, 9, 0), now: TS.now, calendar: cal), "v pátek 9. 10. v 9:00")
        XCTAssertEqual(CzechFormat.relativeDateTime(TS.date(2026, 10, 8, 9, 0), now: TS.now, calendar: cal), "pozítří v 9:00")
        XCTAssertEqual(CzechFormat.headerDate(TS.now, calendar: cal), "Úterý 6. října")
        XCTAssertEqual(CzechFormat.count(3, "úkol", "úkoly", "úkolů"), "3 úkoly")
        XCTAssertEqual(CzechFormat.count(5, "úkol", "úkoly", "úkolů"), "5 úkolů")
        XCTAssertEqual(CzechFormat.relativeInterval(TS.date(2026, 10, 6, 10, 25), now: TS.now), "za 25 min")
    }
}
