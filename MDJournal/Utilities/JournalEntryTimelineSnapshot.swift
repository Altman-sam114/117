import Foundation

/// A presentation of the visible order, without filtering, sorting, or reading bodies.
struct JournalEntryTimelineSnapshot: Equatable {
    struct Month: Equatable, Identifiable {
        let id: Date
        let title: String
        var entries: [JournalEntry]
    }

    let months: [Month]

    init(
        entries: [JournalEntry],
        calendar: Calendar = .current,
        locale: Locale = .current
    ) {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")

        var months: [Month] = []
        for entry in entries {
            let start = calendar.dateInterval(of: .month, for: entry.createdAt)?.start
                ?? calendar.startOfDay(for: entry.createdAt)
            if months.last?.id == start {
                months[months.count - 1].entries.append(entry)
            } else {
                months.append(Month(
                    id: start,
                    title: formatter.string(from: start),
                    entries: [entry]
                ))
            }
        }
        self.months = months
    }
}
