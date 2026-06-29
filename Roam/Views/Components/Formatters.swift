import Foundation

/// Shared formatting helpers used across the view layer.

/// Formats a duration (in seconds) into a compact human string, e.g. "2h 14m".
/// Falls back to "0m" for zero/negative inputs so the UI never shows an empty cell.
func formattedDuration(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite, seconds > 0 else { return "0m" }

    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .abbreviated
    formatter.maximumUnitCount = 2

    if seconds < 60 {
        formatter.allowedUnits = [.second]
    } else if seconds < 3600 {
        formatter.allowedUnits = [.minute]
    } else if seconds < 86_400 {
        formatter.allowedUnits = [.hour, .minute]
    } else {
        formatter.allowedUnits = [.day, .hour]
    }

    return formatter.string(from: seconds) ?? "0m"
}

/// Formats a date as a relative phrase, e.g. "2 hours ago".
func relativeTime(_ date: Date) -> String {
    date.formatted(.relative(presentation: .named))
}

private let shortDateTimeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    return f
}()

/// Formats a date with medium date + short time, locale aware.
func shortDateTime(_ date: Date) -> String {
    shortDateTimeFormatter.string(from: date)
}

private let timeOnlyFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .none
    f.timeStyle = .short
    return f
}()

/// Formats just the time-of-day, locale aware.
func timeOnly(_ date: Date) -> String {
    timeOnlyFormatter.string(from: date)
}

private let dayHeaderFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .full
    f.timeStyle = .none
    return f
}()

/// Formats a day as a full date suitable for a section header.
func dayHeader(_ date: Date) -> String {
    if Calendar.current.isDateInToday(date) { return "Today" }
    if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
    return dayHeaderFormatter.string(from: date)
}
