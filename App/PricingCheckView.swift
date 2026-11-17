import SwiftUI
import WebKit

/// Shows the live Anthropic pricing page in-app so it can be compared by eye
/// against PricingTable's hardcoded catalog. Deliberately does not parse or
/// auto-match anything — the page lists models by display name only ("Claude
/// Sonnet 5"), never by the API model ID strings the catalog is keyed on, so
/// any automatic diff would be guessing at that mapping.
struct PricingCheckView: View {
    @Environment(\.dismiss) private var dismiss

    private var checkURL: URL {
        URL(string: PricingTable.sourceURL.absoluteString + "#model-pricing") ?? PricingTable.sourceURL
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Live pricing page")
                    .font(.headline)
                Spacer()
                Text("Table last verified \(PricingTable.asOf.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Done") { dismiss() }
            }
            .padding()

            Divider()

            PricingWebView(url: checkURL)
        }
        .frame(width: 860, height: 640)
    }
}

private struct PricingWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        WKWebView()
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard webView.url != url else { return }
        webView.load(URLRequest(url: url))
    }
}
