import SwiftUI
import WidgetKit
import AppIntents

private let groupID = "group.com.fengluo.live2dmetal"
private let widgetKind = "Live2DCharacter"

struct SavedFace: Codable {
    let id: String
    let title: String
    let open: String
    let closed: String
}

enum FaceStore {
    static var root: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)?
            .appendingPathComponent("WidgetFaces", isDirectory: true)
    }
    static var defaults: UserDefaults? { UserDefaults(suiteName: groupID) }
    static func faces() -> [SavedFace] {
        guard let url = root?.appendingPathComponent("faces.json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([SavedFace].self, from: data)) ?? []
    }
    static func selected() -> SavedFace? {
        let items = faces()
        guard !items.isEmpty else { return nil }
        return items[max(0, defaults?.integer(forKey: "faceIndex") ?? 0) % items.count]
    }
}

struct NextFaceIntent: AppIntent {
    static var title: LocalizedStringResource = "切换表情"
    static var openAppWhenRun = false
    func perform() async throws -> some IntentResult {
        let count = FaceStore.faces().count
        if count > 0 {
            let index = FaceStore.defaults?.integer(forKey: "faceIndex") ?? 0
            FaceStore.defaults?.set((max(0, index) + 1) % count, forKey: "faceIndex")
        }
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        return .result()
    }
}

struct BlinkIntent: AppIntent {
    static var title: LocalizedStringResource = "测试眨眼"
    static var openAppWhenRun = false
    func perform() async throws -> some IntentResult {
        FaceStore.defaults?.set(true, forKey: "blinkOnce")
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        return .result()
    }
}

struct AutoBlinkIntent: AppIntent {
    static var title: LocalizedStringResource = "切换三秒眨眼实验"
    static var openAppWhenRun = false
    func perform() async throws -> some IntentResult {
        let enabled = FaceStore.defaults?.bool(forKey: "autoBlink") ?? false
        FaceStore.defaults?.set(!enabled, forKey: "autoBlink")
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        return .result()
    }
}

struct FaceEntry: TimelineEntry {
    let date: Date
    let face: SavedFace?
    var closed = false
    var autoBlink = false
}

struct FaceProvider: TimelineProvider {
    func placeholder(in context: Context) -> FaceEntry { FaceEntry(date: .now, face: nil) }
    func getSnapshot(in context: Context, completion: @escaping (FaceEntry) -> Void) {
        completion(FaceEntry(date: .now, face: FaceStore.selected()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<FaceEntry>) -> Void) {
        let now = Date()
        let face = FaceStore.selected()
        let repeating = FaceStore.defaults?.bool(forKey: "autoBlink") ?? false
        let once = FaceStore.defaults?.bool(forKey: "blinkOnce") ?? false
        FaceStore.defaults?.set(false, forKey: "blinkOnce")
        var entries = [FaceEntry(date: now, face: face, autoBlink: repeating)]
        // A bounded experiment, not a background timer. WidgetKit may coalesce
        // these entries. Always finish with open eyes if it skips a short frame.
        if face != nil && (repeating || once) {
            for index in 0..<(repeating ? 20 : 1) {
                let start = now.addingTimeInterval(repeating ? Double(index + 1) * 3 : 0.5)
                entries.append(FaceEntry(date: start, face: face, closed: true, autoBlink: repeating))
                entries.append(FaceEntry(date: start.addingTimeInterval(0.18), face: face, autoBlink: repeating))
            }
        }
        // Do not ask WidgetKit to run a continual high-frequency refresh loop.
        completion(Timeline(entries: entries, policy: .never))
    }
}

struct FaceWidgetView: View {
    let entry: FaceEntry
    var body: some View {
        VStack(spacing: 3) {
            if let face = entry.face, let root = FaceStore.root,
               let image = UIImage(contentsOfFile: root.appendingPathComponent(entry.closed ? face.closed : face.open).path) {
                Image(uiImage: image).resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .scaledToFit()
                    .accessibilityLabel(entry.closed ? "闭眼" : face.title)
            } else {
                Spacer()
                Text("在应用的表情页\n保存画面到小组件").font(.caption).multilineTextAlignment(.center)
                Spacer()
            }
            HStack(spacing: 8) {
                Button(intent: NextFaceIntent()) { Image(systemName: "face.smiling") }
                    .accessibilityLabel("切换已保存表情")
                Button(intent: BlinkIntent()) { Image(systemName: "eye") }
                    .accessibilityLabel("测试一次眨眼")
                Button(intent: AutoBlinkIntent()) {
                    Text(entry.autoBlink ? "停止" : "3s试验").font(.caption2)
                }
            }.buttonStyle(.plain).padding(.vertical, 5)
        }
        .transaction { $0.animation = nil }
        .containerBackground(Color(red: 0.06, green: 0.09, blue: 0.14), for: .widget)
    }
}

@main
struct Live2DWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: widgetKind, provider: FaceProvider()) { FaceWidgetView(entry: $0) }
            .configurationDisplayName("Live2D 表情")
            .description("切换已保存表情，测试短暂眨眼。3 秒眨眼仅试验一分钟，系统可能跳帧。")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
