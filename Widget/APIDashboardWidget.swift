import WidgetKit
import SwiftUI

struct APIDashboardWidget: Widget {
    nonisolated static let kind = "APIDashboardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: Provider()) { entry in
            APIDashboardWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("API Spend")
        .description("Today's and month-to-date Claude API spend and token usage.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct APIDashboardWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DashboardEntry

    var body: some View {
        if !entry.hasAPIKey || entry.snapshot == nil {
            SetupPromptView()
        } else if let snapshot = entry.snapshot {
            switch family {
            case .systemSmall:
                SmallDashboardView(snapshot: snapshot)
            case .systemMedium:
                MediumDashboardView(snapshot: snapshot)
            default:
                LargeDashboardView(snapshot: snapshot)
            }
        }
    }
}

#Preview(as: .systemSmall) {
    APIDashboardWidget()
} timeline: {
    DashboardEntry(date: .now, snapshot: .placeholder)
}

#Preview(as: .systemMedium) {
    APIDashboardWidget()
} timeline: {
    DashboardEntry(date: .now, snapshot: .placeholder)
}

#Preview(as: .systemLarge) {
    APIDashboardWidget()
} timeline: {
    DashboardEntry(date: .now, snapshot: .placeholder)
}
