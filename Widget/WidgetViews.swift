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
            Text("TODAY (EST.)")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            Text(snapshot.estimatedTodaySpendDollars.asCurrency)
                .font(.title.monospacedDigit().bold())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Spacer(minLength: 2)
            SpendSparkline(values: snapshot.spendHistoryDollars)
                .frame(height: 22)
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
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 0) {
                statColumn(title: "TODAY (EST.)", value: snapshot.estimatedTodaySpendDollars.asCurrency)
                Divider()
                statColumn(title: "THIS MONTH", value: snapshot.monthToDateSpendDollars.asCurrency)
            }
            SpendSparkline(values: snapshot.spendHistoryDollars)
                .frame(height: 28)
                .padding(.horizontal, 8)
        }
        .padding(4)
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
                statColumn(title: "TODAY (EST.)", value: snapshot.estimatedTodaySpendDollars.asCurrency)
                statColumn(title: "THIS MONTH", value: snapshot.monthToDateSpendDollars.asCurrency)
            }

            Divider()

            HStack(spacing: 0) {
                statColumn(title: "INPUT TOKENS", value: snapshot.todayInputTokens.asCompact, big: false)
                statColumn(title: "OUTPUT TOKENS", value: snapshot.todayOutputTokens.asCompact, big: false)
            }

            SpendSparkline(values: snapshot.spendHistoryDollars)
                .frame(height: 44)

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Text("Updated \(snapshot.generatedAt.formatted(date: .omitted, time: .shortened))")
                if snapshot.unpricedUsageCount > 0 {
                    Text("· \(snapshot.unpricedUsageCount) unpriced")
                }
            }
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
