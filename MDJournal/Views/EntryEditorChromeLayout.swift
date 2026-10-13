import SwiftUI

/// Bound the independently scrollable header so writing remains reachable at low heights.
enum EntryEditorChromeLayout {
    static func isCompactHeight(_ height: CGFloat) -> Bool { height < 400 }

    static func usesInlineTools(availableHeight: CGFloat, dynamicTypeSize: DynamicTypeSize) -> Bool {
        isCompactHeight(availableHeight) || dynamicTypeSize.isAccessibilitySize
    }

    static func headerHeight(
        availableHeight: CGFloat,
        showsDetails: Bool,
        dynamicTypeSize: DynamicTypeSize
    ) -> CGFloat {
        if isCompactHeight(availableHeight) && !showsDetails {
            return min(52, max(0, availableHeight) * 0.22)
        }
        let preferred: CGFloat = showsDetails ? 300 : (dynamicTypeSize.isAccessibilitySize ? 220 : 140)
        return min(preferred, max(0, availableHeight) * 0.38)
    }
}
