import Foundation

struct CarCalculator {
    let car: Car

    private var sortedFuelEntries: [FuelEntry] {
        car.fuelEntries.sorted { $0.date < $1.date }
    }

    private var odometerBaseline: Double? {
        car.initialOdometer
    }

    // MARK: - All-time

    var totalKmDriven: Double {
        let e = sortedFuelEntries
        guard let last = e.last else { return 0 }
        let start = odometerBaseline ?? e.first?.odometerReading
        guard let start else { return 0 }
        return max(0, last.odometerReading - start)
    }

    // MARK: - Period helpers

    // Uses the full-tank method: only measure km/liters over spans between two consecutive
    // "filledToFull" entries. Partial fill-ups in between contribute their liters but the
    // segment boundaries are anchored to full-tank entries so efficiency stays accurate.
    private func tripData(from start: Date, to end: Date) -> (km: Double, liters: Double) {
        let entries = sortedFuelEntries
        var km = 0.0, liters = 0.0

        // Find the index of the last full-tank entry strictly before `start`, which acts as
        // the anchor odometer for the first segment that falls inside the window.
        var segmentStartIndex: Int? = nil
        for (index, entry) in entries.enumerated() {
            if entry.date < start && entry.filledToFull {
                segmentStartIndex = index
            }
        }

        // Walk forward through entries that end inside [start, end].
        // A segment closes when we hit a filledToFull entry; accumulate liters for every
        // entry in the segment, and km from the segment-open odometer to the close odometer.
        var pendingLiters = 0.0
        var segmentOpenOdometer: Double? = segmentStartIndex.map { entries[$0].odometerReading }
            ?? odometerBaseline

        for (index, entry) in entries.enumerated() {
            // Skip entries before our anchor
            if let anchor = segmentStartIndex, index <= anchor { continue }

            pendingLiters += entry.liters

            if entry.filledToFull {
                // Segment closes here
                if entry.date >= start && entry.date <= end, let openOdo = segmentOpenOdometer {
                    km += max(0, entry.odometerReading - openOdo)
                    liters += pendingLiters
                }
                pendingLiters = 0.0
                segmentOpenOdometer = entry.odometerReading
            }
        }

        return (km, liters)
    }

    func kmDriven(from start: Date, to end: Date) -> Double {
        tripData(from: start, to: end).km
    }

    func fuelCost(from start: Date, to end: Date) -> Double {
        car.fuelEntries
            .filter { $0.date >= start && $0.date <= end }
            .reduce(0) { $0 + $1.totalCost }
    }

    func fuelEfficiency(from start: Date, to end: Date) -> Double? {
        let (km, liters) = tripData(from: start, to: end)
        guard km > 0 else { return nil }
        return (liters / km) * 100
    }

    func recurringCostTotal(from start: Date, to end: Date) -> Double {
        var total = 0.0
        for cost in car.recurringCosts {
            let s = max(cost.startDate, start)
            let e = min(cost.endDate ?? end, end)
            guard s <= e else { continue }
            total += cost.monthlyAmount * monthsBetween(s, and: e)
        }
        return total
    }

    func otherCostTotal(from start: Date, to end: Date) -> Double {
        car.otherCosts
            .filter { $0.date >= start && $0.date <= end }
            .reduce(0) { $0 + $1.amount }
    }

    var amortizationPerKm: Double? {
        guard let resale = car.currentResaleValue else { return nil }
        let km = totalKmDriven
        guard km > 0 else { return nil }
        return max(0, car.purchasePrice - resale) / km
    }

    func costPerKmFuelOnly(from start: Date, to end: Date) -> Double? {
        let km = kmDriven(from: start, to: end)
        guard km > 0 else { return nil }
        return fuelCost(from: start, to: end) / km
    }

    func costPerKmTotal(from start: Date, to end: Date) -> Double? {
        let km = kmDriven(from: start, to: end)
        guard km > 0 else { return nil }
        let fuel = fuelCost(from: start, to: end)
        let recurring = recurringCostTotal(from: start, to: end)
        let other = otherCostTotal(from: start, to: end)
        let amort = (amortizationPerKm ?? 0) * km
        return (fuel + recurring + other + amort) / km
    }

    // MARK: - Breakdown for charts

    func costBreakdown(from start: Date, to end: Date) -> [(label: String, value: Double)] {
        let km = kmDriven(from: start, to: end)
        let fuel = fuelCost(from: start, to: end)
        let recurring = recurringCostTotal(from: start, to: end)
        let other = otherCostTotal(from: start, to: end)
        let amort = (amortizationPerKm ?? 0) * km

        var result: [(String, Double)] = []
        if fuel > 0 { result.append(("Fuel", fuel)) }
        if amort > 0 { result.append(("Amortization", amort)) }
        if recurring > 0 { result.append(("Recurring", recurring)) }
        if other > 0 { result.append(("Other Costs", other)) }
        return result
    }

    // Monthly fuel costs for chart (last N months)
    func monthlyFuelCosts(months: Int = 12) -> [(month: Date, cost: Double)] {
        let cal = Calendar.current
        let now = Date()
        var result: [(Date, Double)] = []
        for offset in 0..<months {
            guard let monthStart = cal.date(byAdding: .month, value: -offset, to: cal.startOfMonth(for: now)),
                  let nextMonth = cal.date(byAdding: .month, value: 1, to: monthStart),
                  let monthEnd = cal.date(byAdding: .second, value: -1, to: nextMonth)
            else { continue }
            result.append((monthStart, fuelCost(from: monthStart, to: monthEnd)))
        }
        return Array(result.reversed())
    }

    // Price per litre for each fill-up, oldest first
    var fuelPriceTrend: [(date: Date, price: Double)] {
        sortedFuelEntries.map { ($0.date, $0.pricePerLiter) }
    }

    // Per-segment efficiency for line chart, using the full-tank method.
    // Each data point spans from one full-tank fill-up to the next, accumulating
    // liters from any partial fill-ups in between.
    var tripEfficiencies: [(date: Date, l100km: Double)] {
        let entries = sortedFuelEntries
        var result: [(Date, Double)] = []
        var segmentOpenOdometer: Double? = odometerBaseline
        var pendingLiters = 0.0

        for entry in entries {
            pendingLiters += entry.liters

            guard entry.filledToFull else { continue }
            guard let openOdo = segmentOpenOdometer else {
                segmentOpenOdometer = entry.odometerReading
                pendingLiters = 0.0
                continue
            }

            let km = max(0, entry.odometerReading - openOdo)
            if km > 0 {
                result.append((entry.date, (pendingLiters / km) * 100))
            }
            segmentOpenOdometer = entry.odometerReading
            pendingLiters = 0.0
        }

        return result
    }

    // MARK: - Resale prompt

    var shouldShowResalePrompt: Bool {
        switch car.promptSchedule {
        case .never: return false
        case .monthly:
            guard let last = car.lastResalePromptDate else { return true }
            return !Calendar.current.isDate(last, equalTo: Date(), toGranularity: .month)
        case .yearly:
            guard let last = car.lastResalePromptDate else { return true }
            return !Calendar.current.isDate(last, equalTo: Date(), toGranularity: .year)
        }
    }

    // MARK: - Helpers

    private func monthsBetween(_ start: Date, and end: Date) -> Double {
        let c = Calendar.current.dateComponents([.month, .day], from: start, to: end)
        return Double(c.month ?? 0) + Double(c.day ?? 0) / 30.0
    }
}

// MARK: - Calendar helper

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}
