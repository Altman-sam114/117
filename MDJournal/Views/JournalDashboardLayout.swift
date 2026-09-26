import SwiftUI

enum JournalDashboardLayout {
    static func columnCount(width: CGFloat, dynamicTypeSize: DynamicTypeSize) -> Int {
        width >= 820 && !dynamicTypeSize.isAccessibilitySize ? 2 : 1
    }
}
