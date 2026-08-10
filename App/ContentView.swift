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
            }

            if let message = model.statusMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(model.statusIsError ? .red : .secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 420, height: model.snapshot == nil ? 300 : 420)
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
                statTile(title: "Today", value: snapshot.todaySpendDollars.asCurrency)
                statTile(title: "This month", value: snapshot.monthToDateSpendDollars.asCurrency)
            }

            HStack(spacing: 24) {
                statTile(title: "Input tokens (today)", value: snapshot.todayInputTokens.asCompact)
                statTile(title: "Output tokens (today)", value: snapshot.todayOutputTokens.asCompact)
            }

            Button("Refresh Now") {
                Task { await model.refresh() }
            }
            .disabled(model.isLoading)
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
