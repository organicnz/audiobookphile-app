//
//  TimeFormatter.swift
//  AudiobookphileClient
//
//  Duration and time formatting utilities
//

import Foundation

enum TimeFormatter {

    /// Format seconds to timestamp (HH:MM:SS or MM:SS)
    static func timestamp(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }

        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    /// Format seconds to readable duration (e.g., "2h 30m" or "45 min")
    static func duration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0 min" }

        let totalMinutes = Int(seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(hours) hour\(hours > 1 ? "s" : "")"
            }
        } else {
            return "\(minutes) min"
        }
    }

    /// Format seconds to short duration (e.g., "2:30" for hours:minutes)
    static func shortDuration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }

        let totalMinutes = Int(seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return String(format: "%d:%02d", hours, minutes)
        } else {
            return "\(minutes)m"
        }
    }

    /// Format remaining time (e.g., "-1:30:45" or "-30:00")
    static func remaining(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "-0:00" }
        return "-" + timestamp(seconds)
    }

    /// Format time remaining with playback rate (adjusted for speed)
    static func adjustedRemaining(_ seconds: TimeInterval, rate: Double) -> String {
        guard rate > 0 else { return remaining(seconds) }
        return remaining(seconds / rate)
    }

    /// Format date to relative string (e.g., "Today", "Yesterday", "3 days ago")
    static func relative(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
            if days < 7 {
                return "\(days) days ago"
            } else if days < 30 {
                let weeks = days / 7
                return "\(weeks) week\(weeks > 1 ? "s" : "") ago"
            } else {
                let months = days / 30
                return "\(months) month\(months > 1 ? "s" : "") ago"
            }
        }
    }

    /// Format a Date to a timestamp string (e.g., "Dec 21, 2024 at 6:30 PM")
    static func dateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Format sleep timer value
    static func sleepTimer(_ minutes: Int) -> String {
        if minutes == -1 {
            return "End of Chapter"
        } else if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins > 0 {
                return "\(hours)h \(mins)m"
            }
            return "\(hours) hour\(hours > 1 ? "s" : "")"
        } else {
            return "\(minutes) min"
        }
    }

    /// Format sleep timer remaining (seconds to "Xm" or "Xs")
    static func sleepTimerRemaining(_ seconds: Int) -> String {
        if seconds > 91 {
            return "\(Int(ceil(Double(seconds) / 60)))m"
        } else {
            return "\(seconds)s"
        }
    }

    /// Parse a timestamp string to seconds (supports HH:MM:SS and MM:SS)
    static func parseTimestamp(_ string: String) -> TimeInterval? {
        let parts = string.split(separator: ":").compactMap { Int($0) }

        switch parts.count {
        case 2: // MM:SS
            return TimeInterval(parts[0] * 60 + parts[1])
        case 3: // HH:MM:SS
            return TimeInterval(parts[0] * 3600 + parts[1] * 60 + parts[2])
        default:
            return nil
        }
    }
}

// MARK: - TimeInterval Extension

extension TimeInterval {
    /// Formatted as timestamp (e.g., "1:30:45")
    var timestamp: String {
        TimeFormatter.timestamp(self)
    }

    /// Formatted as duration (e.g., "1h 30m")
    var durationString: String {
        TimeFormatter.duration(self)
    }

    /// Formatted as remaining time (e.g., "-1:30:45")
    var remainingString: String {
        TimeFormatter.remaining(self)
    }
}

// MARK: - Preview

#if DEBUG
struct TimeFormatterPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timestamp: \(TimeFormatter.timestamp(5445))")
            Text("Duration: \(TimeFormatter.duration(5445))")
            Text("Short: \(TimeFormatter.shortDuration(5445))")
            Text("Remaining: \(TimeFormatter.remaining(5445))")
            Text("Adjusted (1.5x): \(TimeFormatter.adjustedRemaining(5445, rate: 1.5))")
            Text("Relative: \(TimeFormatter.relative(from: Date().addingTimeInterval(-86400 * 3)))")
            Text("Sleep Timer: \(TimeFormatter.sleepTimer(90))")
        }
        .padding()
    }
}

import SwiftUI
#Preview("Time Formatter") {
    TimeFormatterPreview()
}
#endif
