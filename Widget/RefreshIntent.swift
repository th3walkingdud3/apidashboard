import AppIntents
import WidgetKit

/// Lets the widget's own refresh button ask WidgetKit for an immediate
/// timeline reload, bypassing the system's usual refresh-budget scheduling.
/// Runs entirely inside the widget extension process — no need to launch
/// the companion app. The actual network fetch still happens in
/// `Provider.getTimeline`, same as any other reload.
struct RefreshWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh"
    static var description = IntentDescription("Fetches the latest Claude API spend and usage data.")

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadTimelines(ofKind: APIDashboardWidget.kind)
        return .result()
    }
}
