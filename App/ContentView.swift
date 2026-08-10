import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var model = DashboardViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            keySection

            if let snapshot = model.snapshot {
                Divider()
                snapshotSection(snapshot)
                Divider()
                pricingSection(snapshot)
            }

            if let message = model.statusMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(model.statusIsError ? .red : .secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 420, height: model.snapshot == nil ? 300 : 520)
        .task {
            if model.hasSavedKey {
                await model.refresh()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("API Dashboard")
                .font(.title2.bold())
            Text("Shows your Claude API spend and usage in a desktop widget.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var keySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Admin API Key")
                .font(.headline)
            Text("Requires an org **admin** role. Generate one in the Console under Settings → Admin Keys. This key can manage your whole organization, not just read usage — keep it private.")
                .font(.caption)
                .foregroundStyle(.secondary)

            SecureField("sk-ant-admin...", text: $model.apiKey)
                .textFieldStyle(.roundedBorder)
                .disableAutocorrection(true)

            HStack {
                Button("Save & Test") { model.saveKey() }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.apiKey.trimmingCharacters(in: .whitespaces).isEmpty)

                if model.hasSavedKey {
                    Button("Remove Key", role: .destructive) { model.clearKey() }
                }

                Spacer()

                if model.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }

    private func snapshotSection(_ snapshot: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let org = snapshot.organizationName {
                Text(org)
                    .font(.subheadline.bold())
            }

            HStack(spacing: 24) {
                statTile(title: "Today (est.)", value: snapshot.estimatedTodaySpendDollars.asCurrency)
                statTile(title: "This month", value: snapshot.monthToDateSpendDollars.asCurrency)
            }

            HStack(spacing: 24) {
                statTile(title: "Input tokens (today)", value: snapshot.todayInputTokens.asCompact)
                statTile(title: "Output tokens (today)", value: snapshot.todayOutputTokens.asCompact)
            }

            Text("\"Today\" is estimated from live token usage — Anthropic's cost API only finalizes a day's spend once it closes (UTC). \"This month\" combines that estimate with finalized prior days.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button("Refresh Now") {
                Task { await model.refresh() }
            }
            .disabled(model.isLoading)
        }
    }

    private func pricingSection(_ snapshot: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pricing table")
                .font(.headline)

            HStack {
                Text("Last verified \(PricingTable.asOf.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(PricingTable.isPossiblyStale ? .orange : .secondary)
                Spacer()
                Button("View current pricing ↗") {
                    NSWorkspace.shared.open(PricingTable.sourceURL)
                }
                .buttonStyle(.link)
                .font(.caption)
            }

            if PricingTable.isPossiblyStale {
                Text("It's been over \(PricingTable.staleAfterDays) days since this was checked — worth comparing against the page above.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            if snapshot.unpricedUsageCount > 0 {
                Text("⚠️ \(snapshot.unpricedUsageCount) usage record(s) today used a model or service tier not in the pricing table — \"Today (est.)\" excludes them and is a floor, not exact.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func statTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.monospacedDigit().bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
}
