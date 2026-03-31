import Foundation

struct CarCalculator {
    let car: Car

    private var sortedFuelEntries: [FuelEntry] {
        car.fuelEntries.sorted { $0.date < $1.date }
    }

    // MARK: - All-time

    var totalKmDriven: Double {
        let e = sortedFuelEntries
        guard e.count >= 2 else { return 0 }
        return max(0, e.last!.odometerReading - e.first!.odometerReading)
    }

    // MARK: - Period helpers

    // Each fill-up entry (except the first ever) represents a trip from the previous odometer to this one.
    // km and liters are attributed to the date of the later fill-up.
    private func tripData(from start: Date, to end: Date) -> (km: Double, liters: Double) {
        let entries = sortedFuelEntries
        guard entries.count >= 2 else { return (0.0, 0.0) }
        var km = 0.0, liters = 0.0
        for i in 1..<entries.count {
            let e = entries[i]
            guard e.date >= start && e.date <= end else { continue }
            km += max(0, e.odometerReading - entries[i - 1].odometerReading)
            liters += e.liters
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

    // Per-trip efficiency for line chart
    var tripEfficiencies: [(date: Date, l100km: Double)] {
        let entries = sortedFuelEntries
        guard entries.count >= 2 else { return [] }
        var result: [(Date, Double)] = []
        for i in 1..<entries.count {
            let e = entries[i]
            let km = max(0, e.odometerReading - entries[i - 1].odometerReading)
            guard km > 0 else { continue }
            result.append((e.date, (e.liters / km) * 100))
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
