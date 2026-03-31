import SwiftUI
import SwiftData

struct DashboardView: View {
    let car: Car
    @Environment(\.modelContext) private var modelContext

    @State private var selectedPeriod: Period = .thisMonth
    @State private var customStart: Date = Calendar.current.startOfMonth(for: Date())
    @State private var customEnd: Date = Date()
    @State private var showCustomPicker = false
    @State private var showResaleSheet = false
    @State private var showAddFuel = false
    @State private var resaleDismissed = false

    private var calc: CarCalculator { CarCalculator(car: car) }

    private var range: (start: Date, end: Date) {
        dateRange(for: selectedPeriod, customStart: customStart, customEnd: customEnd, carPurchaseDate: car.purchaseDate)
    }

    private var fuelOnlyCost: Double? { calc.costPerKmFuelOnly(from: range.start, to: range.end) }
    private var totalCost: Double? { calc.costPerKmTotal(from: range.start, to: range.end) }
    private var km: Double { calc.kmDriven(from: range.start, to: range.end) }
    private var efficiency: Double? { calc.fuelEfficiency(from: range.start, to: range.end) }
    private var fuelSpent: Double { calc.fuelCost(from: range.start, to: range.end) }
    private var showResaleBanner: Bool { !resaleDismissed && calc.shouldShowResalePrompt }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 20) {

                        // Header
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(car.name)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                if let odometer = car.latestOdometer {
                                    Text("\(Int(odometer).formatted()) km on clock")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            }
                            Spacer()
                            Image(systemName: "car.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        // Period picker
                        VStack(spacing: 12) {
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
                                        Text("From")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.6))
                                        DatePicker("", selection: $customStart, displayedComponents: .date)
                                            .datePickerStyle(.compact)
                                            .labelsHidden()
                                            .colorScheme(.dark)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 8)
                                            .glassEffect(in: RoundedRectangle(cornerRadius: 10))
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("To")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.6))
                                        DatePicker("", selection: $customEnd, in: customStart..., displayedComponents: .date)
                                            .datePickerStyle(.compact)
                                            .labelsHidden()
                                            .colorScheme(.dark)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 8)
                                            .glassEffect(in: RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.horizontal)

                        // Main metrics
                        HStack(spacing: 12) {
                            MetricCard(
                                title: "Fuel Only",
                                subtitle: "per km",
                                value: fuelOnlyCost.map { formatCostPerKm($0) },
                                icon: "fuelpump.fill",
                                accentColor: .ccAmber
                            )
                            MetricCard(
                                title: "Total Cost",
                                subtitle: "per km",
                                value: totalCost.map { formatCostPerKm($0) },
                                icon: "chart.pie.fill",
                                accentColor: .ccTeal
                            )
                        }
                        .padding(.horizontal)

                        // Stats row
                        HStack(spacing: 8) {
                            StatBadge(label: "Distance", value: formatKm(km), icon: "road.lanes")
                            StatBadge(label: "Efficiency", value: efficiency.map { formatEfficiency($0) } ?? "--", icon: "leaf.fill")
                            StatBadge(label: "Fuel", value: formatEUR(fuelSpent), icon: "fuelpump.circle.fill")
                        }
                        .padding(.horizontal)

                        // Amortization info
                        if let resale = car.currentResaleValue {
                            AmortizationCard(car: car, resaleValue: resale, calc: calc)
                                .padding(.horizontal)
                        }

                        // Resale value prompt banner
                        if showResaleBanner {
                            ResalePromptBanner(
                                onUpdate: { showResaleSheet = true },
                                onDismiss: {
                                    car.lastResalePromptDate = Date()
                                    resaleDismissed = true
                                }
                            )
                            .padding(.horizontal)
                        }

                        // Recent activity
                        RecentActivitySection(car: car)
                            .padding(.horizontal)
                            .padding(.bottom, 100)
                    }
                    .padding(.top)
                }
            }
            .navigationBarHidden(true)
            .safeAreaInset(edge: .bottom) {
                LogFuelFAB { showAddFuel = true }
                    .padding(.bottom, 8)
            }
            .sheet(isPresented: $showAddFuel) {
                AddFuelView(car: car)
            }
            .sheet(isPresented: $showResaleSheet) {
                AddResaleValueSheet(car: car) {
                    car.lastResalePromptDate = Date()
                    resaleDismissed = true
                }
            }
        }
    }
}

// MARK: - Log Fuel FAB

struct LogFuelFAB: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "fuelpump.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("Log Fill-Up")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.black.opacity(0.85))
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(Color.ccAmber)
                    .shadow(color: Color.ccAmber.opacity(0.5), radius: 16, x: 0, y: 6)
            )
        }
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let title: String
    let subtitle: String
    let value: String?
    let icon: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(accentColor)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            if let v = value {
                Text(v)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            } else {
                Text("--")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.25))
                Text("add data")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassEffect(in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Amortization Card

struct AmortizationCard: View {
    let car: Car
    let resaleValue: Double
    let calc: CarCalculator

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Amortization", systemImage: "arrow.down.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                if let rate = calc.amortizationPerKm {
                    Text("\(formatCostPerKm(rate))/km")
                        .font(.caption.bold())
                        .foregroundStyle(Color.ccAmber)
                }
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Paid")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(formatEUR(car.purchasePrice))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.3))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current value")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(formatEUR(resaleValue))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Lost value")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(formatEUR(max(0, car.purchasePrice - resaleValue)))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.ccEmber)
                }
            }
        }
        .padding(16)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Resale Prompt Banner

struct ResalePromptBanner: View {
    let onUpdate: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.ccAmber)
            VStack(alignment: .leading, spacing: 2) {
                Text("Update resale value")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text("Keep your amortization accurate")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            Button(action: onUpdate) {
                Text("Update")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.white)
            }
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(14)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.ccAmber.opacity(0.45), lineWidth: 1)
        )
    }
}

// MARK: - Recent Activity

struct RecentActivitySection: View {
    let car: Car

    private var recentEntries: [(date: Date, icon: String, title: String, subtitle: String, amount: String)] {
        var entries: [(date: Date, icon: String, title: String, subtitle: String, amount: String)] = []

        let sortedFuel = car.fuelEntries.sorted { $0.date > $1.date }.prefix(3)
        for e in sortedFuel {
            entries.append((date: e.date, icon: "fuelpump.fill", title: "Fuel", subtitle: "\(formatLiters(e.liters)) at \(formatEUR(e.pricePerLiter))/L", amount: formatEUR(e.totalCost)))
        }

        let sortedCosts = car.otherCosts.sorted { $0.date > $1.date }.prefix(3)
        for c in sortedCosts {
            entries.append((date: c.date, icon: c.category.systemImage, title: c.name, subtitle: c.category.rawValue, amount: formatEUR(c.amount)))
        }

        return Array(entries.sorted { $0.date > $1.date }.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .foregroundStyle(.white)

            if recentEntries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.dashed")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.3))
                    Text("No entries yet — log your first fill-up")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .glassEffect(in: RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentEntries.enumerated()), id: \.offset) { idx, entry in
                        HStack(spacing: 12) {
                            Image(systemName: entry.icon)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                                Text(entry.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(entry.amount)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        if idx < recentEntries.count - 1 {
                            Divider()
                                .background(.white.opacity(0.1))
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .glassEffect(in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

// MARK: - Add Resale Value Sheet

struct AddResaleValueSheet: View {
    let car: Car
    let onSave: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var valueText = ""
    @State private var date = Date()

    private var canSave: Bool {
        Double(valueText.replacingOccurrences(of: ",", with: ".")) != nil
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    Text("Current Resale Value")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("What could you sell your car for today?")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                VStack(spacing: 16) {
                    GlassInputField(title: "Resale value (EUR)", text: $valueText, placeholder: "e.g. 18500", keyboardType: .decimalPad)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Date")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 24)

                HStack(spacing: 12) {
                    Button("Skip") {
                        car.lastResalePromptDate = Date()
                        onSave()
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white.opacity(0.7))

                    Button("Save") {
                        guard let value = Double(valueText.replacingOccurrences(of: ",", with: ".")) else { return }
                        let entry = ResaleValueEntry(date: date, value: value)
                        entry.car = car
                        modelContext.insert(entry)
                        car.lastResalePromptDate = Date()
                        onSave()
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.4)
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .presentationBackground(ccBaseColor)
    }
}
