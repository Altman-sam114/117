import SwiftUI

internal enum EntryRowLayoutAxis: Equatable {
    case horizontal
    case vertical
}

internal struct EntryRowLayoutContract: Equatable {
    let metadataAxis: EntryRowLayoutAxis
    let footerAxis: EntryRowLayoutAxis
    let titleLineLimit: Int?
    let sectionTitleLineLimit: Int
    let usesVerticalSectionLayout: Bool

    init(dynamicTypeSize: DynamicTypeSize) {
        let isAccessibilitySize = dynamicTypeSize.isAccessibilitySize

        metadataAxis = isAccessibilitySize ? .vertical : .horizontal
        footerAxis = isAccessibilitySize ? .vertical : .horizontal
        titleLineLimit = isAccessibilitySize ? nil : 1
        sectionTitleLineLimit = isAccessibilitySize ? 2 : 1
        usesVerticalSectionLayout = isAccessibilitySize
    }
}

struct EntryRowView: View {
    let entry: JournalEntry
    var isSelected = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = EntryRowLayoutContract(dynamicTypeSize: dynamicTypeSize)
        let bodySummary = entry.bodySummary

        VStack(alignment: .leading, spacing: 11) {
            metadata(layout: layout)

            Text(entry.displayTitle)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(layout.titleLineLimit)

            Text(bodySummary.excerpt)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            sectionStrip(bodySummary, layout: layout)
            footer(bodySummary, layout: layout)
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

    private func metadata(layout: EntryRowLayoutContract) -> some View {
        let metadataLayout = layout.metadataAxis == .horizontal
            ? AnyLayout(HStackLayout(spacing: 8))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 6))

        return metadataLayout {
            categoryLabel
            moodLabel

            if layout.metadataAxis == .horizontal {
                Spacer(minLength: 8)
            }

            dateLabel
        }
        .frame(
            maxWidth: layout.metadataAxis == .vertical ? .infinity : nil,
            alignment: .leading
        )
    }

    private var categoryLabel: some View {
        Label(entry.category.rawValue, systemImage: entry.category.systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(entry.category.tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(entry.category.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private var moodLabel: some View {
        Label(entry.mood.rawValue, systemImage: entry.mood.systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .labelStyle(.iconOnly)
            .frame(width: 28, height: 28)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private var dateLabel: some View {
        Text(entry.createdAt.journalListText)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
    }

    private func footer(
        _ bodySummary: JournalEntryBodySummary,
        layout: EntryRowLayoutContract
    ) -> some View {
        let footerLayout = layout.footerAxis == .horizontal
            ? AnyLayout(HStackLayout(spacing: 8))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 4))

        return footerLayout {
            Label("\(bodySummary.wordCount) 词", systemImage: "text.word.spacing")

            if layout.footerAxis == .horizontal {
                Text("·")
            }

            Label("\(bodySummary.sectionCount) 小节", systemImage: "list.bullet.rectangle")

            if layout.footerAxis == .horizontal {
                Text("·")
            }

            Text("更新于 \(entry.updatedAt.journalRelativeUpdateText)")
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .lineLimit(layout.footerAxis == .horizontal ? 1 : nil)
        .frame(
            maxWidth: layout.footerAxis == .vertical ? .infinity : nil,
            alignment: .leading
        )
    }

    @ViewBuilder
    private func sectionStrip(
        _ bodySummary: JournalEntryBodySummary,
        layout: EntryRowLayoutContract
    ) -> some View {
        if layout.usesVerticalSectionLayout {
            accessibilitySectionStack(bodySummary, layout: layout)
        } else {
            regularSectionStrip(bodySummary, layout: layout)
        }
    }

    private func regularSectionStrip(
        _ bodySummary: JournalEntryBodySummary,
        layout: EntryRowLayoutContract
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if bodySummary.sections.isEmpty {
                    Label("未添加 ### 小节", systemImage: "number")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
                } else {
                    ForEach(bodySummary.sections.prefix(3)) { section in
                        Text(section.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(layout.sectionTitleLineLimit)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .foregroundStyle(entry.category.tint)
                            .background(entry.category.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                    }

                    if bodySummary.sectionCount > 3 {
                        Text("+\(bodySummary.sectionCount - 3)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func accessibilitySectionStack(
        _ bodySummary: JournalEntryBodySummary,
        layout: EntryRowLayoutContract
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if bodySummary.sections.isEmpty {
                Label("未添加 ### 小节", systemImage: "number")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
            } else {
                ForEach(bodySummary.sections.prefix(3)) { section in
                    Text(section.title)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(layout.sectionTitleLineLimit)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .foregroundStyle(entry.category.tint)
                        .background(entry.category.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                }

                if bodySummary.sectionCount > 3 {
                    Text("+\(bodySummary.sectionCount - 3)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
