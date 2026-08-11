import Charts
import SwiftUI

/// A minimal trend line: no axes, no labels — just the shape of recent daily
/// spend. The last point (today) is drawn hollow to mark it as a live
/// estimate rather than a finalized day.
struct SpendSparkline: View {
    let values: [Double]

    var body: some View {
        if values.count >= 2 {
            Chart {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Day", index),
                        y: .value("Spend", value)
                    )
                    .interpolationMethod(.linear)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .foregroundStyle(.secondary)
                }

                if let last = values.indices.last {
                    PointMark(
                        x: .value("Day", last),
                        y: .value("Spend", values[last])
                    )
                    .symbolSize(18)
                    .foregroundStyle(.secondary)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: yDomain)
            .chartPlotStyle { $0.padding(0) }
        }
    }

    /// A little headroom above/below so the line doesn't touch the edges,
    /// and a floor so an all-zero history doesn't divide by a zero range.
    private var yDomain: ClosedRange<Double> {
        let maxValue = values.max() ?? 0
        let minValue = values.min() ?? 0
        guard maxValue > minValue else {
            return 0...(maxValue == 0 ? 1 : maxValue * 1.2)
        }
        let padding = (maxValue - minValue) * 0.15
        return max(0, minValue - padding)...(maxValue + padding)
    }
}
