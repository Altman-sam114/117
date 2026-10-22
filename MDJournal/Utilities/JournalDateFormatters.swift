import Foundation

private enum JournalDateFormatters {
    static let listDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans")
        formatter.dateFormat = "M月d日 EEE"
        return formatter
    }()

    static let titleDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()

    static let weekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans")
        formatter.dateFormat = "EEE"
        return formatter
    }()

    static let updatedTime: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_Hans")
        formatter.unitsStyle = .short
        return formatter
    }()
}

extension Date {
    var journalListText: String {
        JournalDateFormatters.listDate.string(from: self)
    }

    var journalTitleText: String {
        JournalDateFormatters.titleDate.string(from: self)
    }

    func journalTimelineText(calendar: Calendar, locale: Locale) -> String {
        formatted(Date.FormatStyle(
            date: .omitted, time: .omitted, locale: locale,
            calendar: calendar, timeZone: calendar.timeZone
        ).day().weekday(.abbreviated))
    }

    var journalWeekdayText: String {
        JournalDateFormatters.weekday.string(from: self)
    }

    var journalRelativeUpdateText: String {
        JournalDateFormatters.updatedTime.localizedString(for: self, relativeTo: Date())
    }
}
