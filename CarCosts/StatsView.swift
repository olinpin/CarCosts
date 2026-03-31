import SwiftUI
import Charts
import SwiftData

struct StatsView: View {
    let car: Car

    @State private var selectedPeriod: Period = .allTime
    @State private var customStart: Date = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    @State private var customEnd: Date = Date()

    private var calc: CarCalculator { CarCalculator(car: car) }

    private var range: (start: Date, end: Date) {
        dateRange(for: selectedPeriod, customStart: customStart, customEnd: customEnd, carPurchaseDate: car.purchaseDate)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        Text("Stats")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ccTextPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        // Period picker
                        VStack(spacing: 10) {
                            Picker("Period", selection: $selectedPeriod) {
                                ForEach(Period.allCases, id: \.self) { p in
                                    Text(p.rawValue).tag(p)
                                }
                            }
                            .pickerStyle(.segmented)
                            .colorScheme(.dark)

                            if selectedPeriod == .custom {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("From").font(.caption2).foregroundStyle(Color.ccTextSecondary)
                                        DatePicker("", selection: $customStart, displayedComponents: .date)
                                            .datePickerStyle(.compact).labelsHidden().colorScheme(.dark)
                                            .padding(8)
                                            .ccCardSurface(cornerRadius: 10)
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("To").font(.caption2).foregroundStyle(Color.ccTextSecondary)
                                        DatePicker("", selection: $customEnd, in: customStart..., displayedComponents: .date)
                                            .datePickerStyle(.compact).labelsHidden().colorScheme(.dark)
                                            .padding(8)
                                            .ccCardSurface(cornerRadius: 10)
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Totals summary
                        totalsSummary

                        // Monthly fuel chart
                        monthlyFuelChart

                        // Efficiency chart
                        efficiencyChart

                        // Cost breakdown
                        costBreakdownChart

                        Spacer(minLength: 100)
                    }
                    .padding(.top)
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Totals Summary

    private var totalsSummary: some View {
        let km = calc.kmDriven(from: range.start, to: range.end)
        let fuel = calc.fuelCost(from: range.start, to: range.end)
        let recurring = calc.recurringCostTotal(from: range.start, to: range.end)
        let other = calc.otherCostTotal(from: range.start, to: range.end)
        let amort = (calc.amortizationPerKm ?? 0) * km
        let total = fuel + recurring + other + amort

        return VStack(alignment: .leading, spacing: 14) {
            Text("Summary")
                .font(.headline)
                .foregroundStyle(Color.ccTextPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                SummaryTile(label: "Total spent", value: formatEUR(total), color: .white)
                SummaryTile(label: "Distance", value: formatKm(km), color: .ccTeal)
                SummaryTile(label: "Fuel", value: formatEUR(fuel), color: .ccAmber)
                SummaryTile(label: "Recurring", value: formatEUR(recurring), color: .ccTeal)
                SummaryTile(label: "Other costs", value: formatEUR(other), color: .ccAmber)
                SummaryTile(label: "Amortization", value: formatEUR(amort), color: .ccEmber)
            }
        }
        .padding(16)
        .ccCardSurface(cornerRadius: 20)
        .padding(.horizontal)
    }

    // MARK: - Monthly Fuel Chart

    private var monthlyFuelChart: some View {
        let data = calc.monthlyFuelCosts(months: 12)
        let hasData = data.contains { $0.cost > 0 }

        return VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Fuel Cost")
                .font(.headline)
                .foregroundStyle(Color.ccTextPrimary)
            Text("Last 12 months")
                .font(.caption)
                .foregroundStyle(Color.ccTextSecondary)

            if hasData {
                Chart(data, id: \.month) { item in
                    BarMark(
                        x: .value("Month", item.month, unit: .month),
                        y: .value("Cost", item.cost)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [Color.ccAmber, Color(red: 1.0, green: 0.75, blue: 0.3)], startPoint: .bottom, endPoint: .top)
                    )
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month, count: 2)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.white.opacity(0.1))
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.white.opacity(0.1))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("€\(Int(v))")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                    }
                }
                .frame(height: 180)
            } else {
                emptyChartPlaceholder("No fuel data yet")
            }
        }
        .padding(16)
        .ccCardSurface(cornerRadius: 20)
        .padding(.horizontal)
    }

    // MARK: - Efficiency Chart

    private var efficiencyChart: some View {
        let data = calc.tripEfficiencies

        return VStack(alignment: .leading, spacing: 12) {
            Text("Fuel Efficiency")
                .font(.headline)
                .foregroundStyle(Color.ccTextPrimary)
            Text("L/100km per fill-up")
                .font(.caption)
                .foregroundStyle(Color.ccTextSecondary)

            if data.count >= 2 {
                Chart(data, id: \.date) { item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("L/100km", item.l100km)
                    )
                    .foregroundStyle(Color.ccTeal)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    PointMark(
                        x: .value("Date", item.date),
                        y: .value("L/100km", item.l100km)
                    )
                    .foregroundStyle(Color.ccTeal)
                    .symbolSize(30)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.white.opacity(0.1))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.white.opacity(0.1))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(format: "%.1f", v))
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                    }
                }
                .frame(height: 180)
            } else {
                emptyChartPlaceholder(data.isEmpty ? "No fill-up data yet" : "Need at least 2 fill-ups")
            }
        }
        .padding(16)
        .ccCardSurface(cornerRadius: 20)
        .padding(.horizontal)
    }

    // MARK: - Cost Breakdown Chart

    private var costBreakdownChart: some View {
        let breakdown = calc.costBreakdown(from: range.start, to: range.end)
        let colors: [Color] = [.ccAmber, .ccEmber, .ccTeal, Color(red: 0.3, green: 0.95, blue: 0.55)]

        return VStack(alignment: .leading, spacing: 12) {
            Text("Cost Breakdown")
                .font(.headline)
                .foregroundStyle(Color.ccTextPrimary)

            if !breakdown.isEmpty {
                HStack(alignment: .center, spacing: 20) {
                    Chart(Array(breakdown.enumerated()), id: \.element.label) { idx, item in
                        SectorMark(
                            angle: .value("Amount", item.value),
                            innerRadius: .ratio(0.55),
                            angularInset: 2
                        )
                        .foregroundStyle(colors[idx % colors.count])
                        .cornerRadius(4)
                    }
                    .frame(width: 140, height: 140)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(breakdown.enumerated()), id: \.element.label) { idx, item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(colors[idx % colors.count])
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.label)
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                    Text(formatEUR(item.value))
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                        }
                    }
                    Spacer()
                }
            } else {
                emptyChartPlaceholder("No cost data for this period")
            }
        }
        .padding(16)
        .ccCardSurface(cornerRadius: 20)
        .padding(.horizontal)
    }

    private func emptyChartPlaceholder(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(Color.ccTextSecondary)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
    }
}

// MARK: - Summary Tile

struct SummaryTile: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.ccTextSecondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .ccCardSurface(cornerRadius: 12)
    }
}
