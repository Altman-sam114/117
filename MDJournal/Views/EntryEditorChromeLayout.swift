import SwiftUI

/// Bound the independently scrollable header so writing remains reachable at low heights.
enum EntryEditorChromeLayout {
    static func isCompactHeight(_ height: CGFloat) -> Bool { height < 400 }

    static func usesInlineTools(
        availableWidth: CGFloat, availableHeight: CGFloat, dynamicTypeSize: DynamicTypeSize
    ) -> Bool {
        availableWidth < 620 || isCompactHeight(availableHeight) || dynamicTypeSize.isAccessibilitySize
    }

    static func headerHeight(
        availableHeight: CGFloat,
        showsDetails: Bool,
        dynamicTypeSize: DynamicTypeSize
    ) -> CGFloat {
        if isCompactHeight(availableHeight) && !showsDetails {
            return min(52, max(0, availableHeight) * 0.22)
        }
        let preferred: CGFloat = showsDetails ? 300 : (dynamicTypeSize.isAccessibilitySize ? 220 : 176)
        return min(preferred, max(0, availableHeight) * 0.38)
    }
}

struct EntryEditorCanvasLayout {
    let horizontalInset: CGFloat
    let verticalInset: CGFloat
    let paperWidth: CGFloat
    let paperHeight: CGFloat
    let cornerRadius: CGFloat

    init(width: CGFloat, height: CGFloat, dynamicTypeSize: DynamicTypeSize, usesSplitPreview: Bool) {
        let showsSurround = width >= EntryEditorLayoutContract.wideLayoutMinimumWidth
            && !EntryEditorChromeLayout.isCompactHeight(height)
            && !dynamicTypeSize.isAccessibilitySize
        horizontalInset = showsSurround ? JournalTheme.canvasInset : 0
        verticalInset = showsSurround ? 18 : 0
        cornerRadius = showsSurround ? 12 : 0
        let availableWidth = max(0, width - horizontalInset * 2)
        paperWidth = showsSurround && !usesSplitPreview
            ? min(availableWidth, JournalTheme.readableWidth + 64)
            : availableWidth
        paperHeight = max(0, height - verticalInset * 2)
    }
}
