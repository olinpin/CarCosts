import SwiftUI
import SwiftData

struct LogsView: View {
    let car: Car
    @Environment(\.modelContext) private var modelContext

    @State private var showFuelLog = false
    @State private var showCostLog = false
    @State private var logTab: LogTab = .fuel

    enum LogTab: String, CaseIterable { case fuel = "Fuel", costs = "Costs" }

    private var sortedFuel: [FuelEntry] {
        car.fuelEntries.sorted { $0.date > $1.date }
    }

    private var sortedCosts: [OtherCost] {
        car.otherCosts.sorted { $0.date > $1.date }
    }

    private var sortedRecurring: [RecurringCost] {
        car.recurringCosts.sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Logs")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Button {
                            if logTab == .fuel { showFuelLog = true }
                            else { showCostLog = true }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                    // Segment
                    Picker("Log type", selection: $logTab) {
                        ForEach(LogTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .colorScheme(.dark)
                    .padding(.horizontal)
                    .padding(.bottom, 12)

                    // Content
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if logTab == .fuel {
                                fuelSection
                            } else {
                                costsSection
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showFuelLog) {
                AddFuelView(car: car)
            }
            .sheet(isPresented: $showCostLog) {
                AddCostView(car: car)
            }
        }
    }

    @ViewBuilder
    private var fuelSection: some View {
        if sortedFuel.isEmpty {
            emptyState(icon: "fuelpump", message: "No fill-ups logged yet")
        } else {
            let entries = Array(sortedFuel.enumerated())
            VStack(spacing: 0) {
                ForEach(entries, id: \.element.persistentModelID) { idx, entry in
                    FuelEntryRow(entry: entry, prev: idx < sortedFuel.count - 1 ? sortedFuel[idx + 1] : nil)
                    if idx < entries.count - 1 {
                        Divider().background(.white.opacity(0.08)).padding(.horizontal, 16)
                    }
                }
            }
            .glassEffect(in: RoundedRectangle(cornerRadius: 18))
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var costsSection: some View {
        VStack(spacing: 16) {
            // Recurring costs
            if !sortedRecurring.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Recurring")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                    ForEach(Array(sortedRecurring.enumerated()), id: \.element.persistentModelID) { idx, cost in
                        RecurringCostRow(cost: cost)
                        if idx < sortedRecurring.count - 1 {
                            Divider().background(.white.opacity(0.08)).padding(.horizontal, 16)
                        }
                    }
                }
                .glassEffect(in: RoundedRectangle(cornerRadius: 18))
            }

            // One-time costs
            if !sortedCosts.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("One-time")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                    ForEach(Array(sortedCosts.enumerated()), id: \.element.persistentModelID) { idx, cost in
                        OtherCostRow(cost: cost)
                        if idx < sortedCosts.count - 1 {
                            Divider().background(.white.opacity(0.08)).padding(.horizontal, 16)
                        }
                    }
                }
                .glassEffect(in: RoundedRectangle(cornerRadius: 18))
            }

            if sortedRecurring.isEmpty && sortedCosts.isEmpty {
                emptyState(icon: "banknote", message: "No costs logged yet")
            }
        }
        .padding(.top, 4)
    }

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.25))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .glassEffect(in: RoundedRectangle(cornerRadius: 18))
        .padding(.top, 4)
    }
}

// MARK: - Fuel Entry Row

struct FuelEntryRow: View {
    let entry: FuelEntry
    let prev: FuelEntry?

    private var kmDriven: Double? {
        guard let prev else { return nil }
        return max(0, entry.odometerReading - prev.odometerReading)
    }

    private var efficiency: Double? {
        guard let km = kmDriven, km > 0 else { return nil }
        return (entry.liters / km) * 100
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "fuelpump.fill")
                .font(.callout)
                .foregroundStyle(Color.ccAmber.opacity(0.85))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(formatLiters(entry.liters))
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    Text("@ \(formatEUR(entry.pricePerLiter))/L")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                HStack(spacing: 8) {
                    Text("\(Int(entry.odometerReading).formatted()) km")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                    if let km = kmDriven {
                        Text("+\(Int(km)) km")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    if let eff = efficiency {
                        Text(formatEfficiency(eff))
                            .font(.caption2)
                            .foregroundStyle(Color.ccTeal.opacity(0.8))
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(formatEUR(entry.totalCost))
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

// MARK: - Recurring Cost Row

struct RecurringCostRow: View {
    let cost: RecurringCost

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: cost.category.systemImage)
                .font(.callout)
                .foregroundStyle(Color.ccTeal.opacity(0.85))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(cost.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(cost.category.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(formatEUR(cost.monthlyAmount))/mo")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text("from \(cost.startDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

// MARK: - Other Cost Row

struct OtherCostRow: View {
    let cost: OtherCost

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: cost.category.systemImage)
                .font(.callout)
                .foregroundStyle(Color.ccAmber.opacity(0.85))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(cost.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    Text(cost.category.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                    if !cost.notes.isEmpty {
                        Text("· \(cost.notes)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.35))
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(formatEUR(cost.amount))
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(cost.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}
