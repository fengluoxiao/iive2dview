import Foundation
import WidgetKit

@objc(Live2DWidgetReloader)
final class Live2DWidgetReloader: NSObject {
    @objc static func reload() {
        WidgetCenter.shared.reloadTimelines(ofKind: "Live2DCharacter")
    }
}
