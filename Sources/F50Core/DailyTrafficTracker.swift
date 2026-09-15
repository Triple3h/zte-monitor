import Foundation

/// 设备不上报 `day_rx_bytes` / `day_tx_bytes` 时的「当日流量」兜底推算
/// （F50 Pro / MU3356 实测 day_* 与 total_* 全部回显空串，只提供 billing 周期累计）。
///
/// 采用「相邻采样增量累加」而不是「当日零点基线差值」：后者一旦设备计数器出现脏值，
/// 基线会变小，整个月度累计就会被当成当日流量（面板表现为「当日流量 ≈ 本月已用」）。
///
/// 计数器回退的两种情况分开处理：
/// - 瞬时脏值：回退后又恢复到原高水位 → 恢复过程不计入（只把高水位抬回真实值）；
/// - 真实重置（换卡 / 设备重启 / 账单周期）：计数器回到低位后重新增长 → 继续按增量累加。
/// 判定依据是「是否回到此前的高水位」，不需要额外持久化就能区分。
public struct DailyTrafficTracker {
    /// 已累计的日期（yyyy-MM-dd）
    public private(set) var day: String
    /// 已入账的高水位采样值
    public private(set) var lastSample: UInt64
    /// 当日已累计的观测增量
    public private(set) var observed: UInt64
    /// 计数器回退后的低位采样（内存态，无需持久化）
    private var dipSample: UInt64?

    public init(day: String = "", lastSample: UInt64 = 0, observed: UInt64 = 0) {
        self.day = day
        self.lastSample = lastSample
        self.observed = observed
        self.dipSample = nil
    }

    /// 记录一次月度累计采样，返回当日已观测到的字节数。
    @discardableResult
    public mutating func record(day today: String, monthlyTotal: UInt64) -> UInt64 {
        // 跨天：当日首次采样只作为基线，不计入增量。
        guard day == today else {
            day = today
            observed = 0
            lastSample = monthlyTotal
            dipSample = nil
            return observed
        }

        if let dip = dipSample {
            // 回到回退前的水平：判定为瞬时脏值，恢复过程不计入。
            if monthlyTotal >= lastSample {
                lastSample = monthlyTotal
                dipSample = nil
                return observed
            }
            // 低位继续增长：判定为真实重置，按低位增量继续累加。
            if monthlyTotal >= dip {
                observed += monthlyTotal - dip
                dipSample = monthlyTotal
                return observed
            }
            // 仍在下跌：只跟随低位，不入账。
            dipSample = monthlyTotal
            return observed
        }

        if monthlyTotal >= lastSample {
            observed += monthlyTotal - lastSample
            lastSample = monthlyTotal
        } else {
            // 计数器回退：先记住低位，等下一次采样判断是脏值还是真实重置。
            dipSample = monthlyTotal
        }

        return observed
    }
}
