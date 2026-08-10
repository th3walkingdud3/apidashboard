import SwiftUI

struct SetupPromptView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "key.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Open API Dashboard to add your Admin API key.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct SmallDashboardView: View {
    let snapshot: DashboardSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TODAY")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            Text(snapshot.todaySpendDollars.asCurrency)
                .font(.title.monospacedDigit().bold())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Spacer()
            Text(snapshot.generatedAt, style: .time)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(4)
    }
}

struct MediumDashboardView: View {
    let snapshot: DashboardSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            statColumn(title: "TODAY", value: snapshot.todaySpendDollars.asCurrency)
            Divider()
            statColumn(title: "THIS MONTH", value: snapshot.monthToDateSpendDollars.asCurrency)
        }
        .padding(4)
        .overlay(alignment: .bottomTrailing) {
            Text(snapshot.generatedAt, style: .time)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding([.trailing, .bottom], 4)
        }
    }

    private func statColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.monospacedDigit().bold())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }
}

struct LargeDashboardView: View {
    let snapshot: DashboardSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let org = snapshot.organizationName {
                Text(org)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                statColumn(title: "TODAY", value: snapshot.todaySpendDollars.asCurrency)
                statColumn(title: "THIS MONTH", value: snapshot.monthToDateSpendDollars.asCurrency)
            }

            Divider()

            HStack(spacing: 0) {
                statColumn(title: "INPUT TOKENS", value: snapshot.todayInputTokens.asCompact, big: false)
                statColumn(title: "OUTPUT TOKENS", value: snapshot.todayOutputTokens.asCompact, big: false)
                statColumn(title: "REQUESTS", value: "\(snapshot.todayRequestCount)", big: false)
            }

            Spacer(minLength: 0)

            Text("Updated \(snapshot.generatedAt.formatted(date: .omitted, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(4)
    }

    private func statColumn(title: String, value: String, big: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            Text(value)
                .font((big ? Font.title2 : Font.headline).monospacedDigit().bold())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
