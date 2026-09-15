import XCTest
@testable import F50Core

final class DailyTrafficTrackerTests: XCTestCase {
    /// 旧实现用「当日零点基线 + 月度累计差值」：基线一旦是脏值（真机上曾只剩 1.8MB），
    /// 整个本月累计会被当成当日流量，面板出现「当日流量 ≈ 本月已用」。增量累加必须免疫脏基线。
    func testDirtyCounterDipDoesNotInflateDailyUsage() {
        let monthly: UInt64 = 83_955_279_238
        var tracker = DailyTrafficTracker()

        // 当日首次采样只作为基线
        XCTAssertEqual(tracker.record(day: "2026-09-15", monthlyTotal: monthly), 0)
        // 之后只累计真实增量
        XCTAssertEqual(tracker.record(day: "2026-09-15", monthlyTotal: monthly + 5_000_000), 5_000_000)
        // 计数器瞬时掉到 1.8MB：不入账
        XCTAssertEqual(tracker.record(day: "2026-09-15", monthlyTotal: 1_890_443), 5_000_000)
        // 恢复到原水位：恢复过程整体不计入，避免把整月累计当当日
        XCTAssertEqual(tracker.record(day: "2026-09-15", monthlyTotal: monthly + 9_000_000), 5_000_000)
        // 恢复正常后继续按增量累加
        XCTAssertEqual(tracker.record(day: "2026-09-15", monthlyTotal: monthly + 11_000_000), 7_000_000)
    }

    func testGenuineCounterResetAtZeroKeepsAccumulating() {
        var tracker = DailyTrafficTracker(day: "2026-09-15", lastSample: 83_955_279_238, observed: 5_000_000)

        // 换卡 / 设备重启导致计数器归零
        XCTAssertEqual(tracker.record(day: "2026-09-15", monthlyTotal: 0), 5_000_000)
        // 归零后的增长仍属于当日
        XCTAssertEqual(tracker.record(day: "2026-09-15", monthlyTotal: 6_000_000), 11_000_000)
    }

    func testResetsAccumulationOnNewDay() {
        var tracker = DailyTrafficTracker(day: "2026-09-15", lastSample: 1_000, observed: 4_096)

        XCTAssertEqual(tracker.record(day: "2026-09-16", monthlyTotal: 5_000), 0)
        XCTAssertEqual(tracker.record(day: "2026-09-16", monthlyTotal: 5_500), 500)
    }

    func testKeepsAccumulationAcrossRestart() {
        // 持久化恢复后（同一天）继续累加，不因重启丢掉当日观测
        var tracker = DailyTrafficTracker(day: "2026-09-15", lastSample: 9_000, observed: 1_000)

        XCTAssertEqual(tracker.record(day: "2026-09-15", monthlyTotal: 9_600), 1_600)
    }
}
