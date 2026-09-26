import SwiftUI

/// Bound the independently scrollable header so writing remains reachable at low heights.
enum EntryEditorChromeLayout {
    static func headerHeight(
        availableHeight: CGFloat,
        showsDetails: Bool,
        dynamicTypeSize: DynamicTypeSize
    ) -> CGFloat {
        let preferred: CGFloat = showsDetails ? 300 : (dynamicTypeSize.isAccessibilitySize ? 220 : 140)
        return min(preferred, max(0, availableHeight) * 0.38)
    }
}
