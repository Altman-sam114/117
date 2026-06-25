import SwiftUI

struct EntryRowView: View {
    let entry: JournalEntry
    var isSelected = false

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Label(entry.category.rawValue, systemImage: entry.category.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(entry.category.tint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(entry.category.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                Label(entry.mood.rawValue, systemImage: entry.mood.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .labelStyle(.iconOnly)
                    .frame(width: 28, height: 28)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))

                Spacer(minLength: 8)

                Text(entry.createdAt.journalListText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(entry.displayTitle)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(entry.excerpt)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            sectionStrip

            HStack(spacing: 8) {
                Label("\(entry.wordCount) 词", systemImage: "text.word.spacing")
                Text("·")
                Label("\(entry.sectionCount) 小节", systemImage: "list.bullet.rectangle")
                Text("·")
                Text("更新于 \(entry.updatedAt.journalRelativeUpdateText)")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .lineLimit(1)
        }
        .padding(14)
        .background(
            isSelected ? entry.category.tint.opacity(0.16) : Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? entry.category.tint.opacity(0.60) : Color.white.opacity(0.48), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }

    private var sectionStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if entry.sections.isEmpty {
                    Label("未添加 ### 小节", systemImage: "number")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
                } else {
                    ForEach(entry.sections.prefix(3)) { section in
                        Text(section.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .foregroundStyle(entry.category.tint)
                            .background(entry.category.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                    }

                    if entry.sections.count > 3 {
                        Text("+\(entry.sections.count - 3)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

extension JournalEntry.Category {
    var tint: Color {
        switch self {
        case .daily:
            return .teal
        case .workStudy:
            return .indigo
        case .inspiration:
            return .orange
        case .travel:
            return .blue
        case .health:
            return .pink
        }
    }
}
