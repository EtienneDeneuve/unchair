import Foundation

/// Presentation-only formatting for Today / Human Runtime. Does not change metrics.
enum HumanStatusFormatting {
    /// “36 min”, “1h 12m”, “50h 18m” — never timer-style `50:18:06`.
    static func friendlyDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            if minutes == 0 { return "\(hours)h" }
            return "\(hours)h \(minutes)m"
        }
        if minutes > 0 { return "\(minutes) min" }
        return "\(total)s"
    }

    static func nextBreakLine(remainingSeconds: TimeInterval?, debtSeconds: TimeInterval?, debtActive: Bool) -> String {
        guard let remainingSeconds else {
            return "Next break —"
        }
        var line = "Next break in \(friendlyDuration(remainingSeconds))"
        if debtActive, let debtSeconds, debtSeconds > 0 {
            line += " · Movement debt \(friendlyDuration(debtSeconds))"
        }
        return line
    }

    static func longestSessionLine(minutes: Int) -> String {
        let seconds = TimeInterval(minutes * 60)
        return "Longest session \(friendlyDuration(seconds))"
    }
}
