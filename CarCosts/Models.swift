import SwiftData
import Foundation

// MARK: - Enums

enum PromptSchedule: String, Codable, CaseIterable {
    case monthly = "Monthly"
    case yearly = "Yearly"
    case never = "Never"
}

enum CostCategory: String, Codable, CaseIterable {
    case insurance = "Insurance"
    case tax = "Road Tax"
    case maintenance = "Maintenance"
    case cosmetic = "Cosmetic"
    case repair = "Repair"
    case parking = "Parking"
    case toll = "Toll"
    case other = "Other"

    var systemImage: String {
        switch self {
        case .insurance: return "shield.fill"
        case .tax: return "doc.text.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .cosmetic: return "sparkles"
        case .repair: return "hammer.fill"
        case .parking: return "parkingsign.circle.fill"
        case .toll: return "road.lanes"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .insurance: return "blue"
        case .tax: return "purple"
        case .maintenance: return "orange"
        case .cosmetic: return "pink"
        case .repair: return "red"
        case .parking: return "teal"
        case .toll: return "green"
        case .other: return "gray"
        }
    }
}

// MARK: - Models

@Model
final class Car {
    var name: String
    var purchasePrice: Double
    var purchaseDate: Date
    var initialOdometer: Double?
    var resalePromptScheduleRaw: String
    var lastResalePromptDate: Date?

    @Relationship(deleteRule: .cascade) var fuelEntries: [FuelEntry] = []
    @Relationship(deleteRule: .cascade) var resaleValueEntries: [ResaleValueEntry] = []
    @Relationship(deleteRule: .cascade) var recurringCosts: [RecurringCost] = []
    @Relationship(deleteRule: .cascade) var otherCosts: [OtherCost] = []
    @Relationship(deleteRule: .cascade) var trips: [Trip] = []

    init(name: String, purchasePrice: Double, purchaseDate: Date, initialOdometer: Double? = nil) {
        self.name = name
        self.purchasePrice = purchasePrice
        self.purchaseDate = purchaseDate
        self.initialOdometer = initialOdometer
        self.resalePromptScheduleRaw = PromptSchedule.monthly.rawValue
    }

    var promptSchedule: PromptSchedule {
        get { PromptSchedule(rawValue: resalePromptScheduleRaw) ?? .monthly }
        set { resalePromptScheduleRaw = newValue.rawValue }
    }

    var currentResaleValue: Double? {
        resaleValueEntries.sorted { $0.date > $1.date }.first?.value
    }

    var latestOdometer: Double? {
        fuelEntries.sorted { $0.date > $1.date }.first?.odometerReading ?? initialOdometer
    }
}

@Model
final class FuelEntry {
    var date: Date
    var liters: Double
    var totalCost: Double
    var pricePerLiter: Double
    var odometerReading: Double
    var filledToFull: Bool = true
    var trip: Trip?
    var car: Car?

    init(date: Date, liters: Double, totalCost: Double, pricePerLiter: Double, odometerReading: Double, filledToFull: Bool = true) {
        self.date = date
        self.liters = liters
        self.totalCost = totalCost
        self.pricePerLiter = pricePerLiter
        self.odometerReading = odometerReading
        self.filledToFull = filledToFull
    }
}

@Model
final class ResaleValueEntry {
    var date: Date
    var value: Double
    var car: Car?

    init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

@Model
final class RecurringCost {
    var name: String
    var monthlyAmount: Double
    var startDate: Date
    var endDate: Date?
    var categoryRaw: String
    var car: Car?

    init(name: String, monthlyAmount: Double, startDate: Date, endDate: Date? = nil, category: CostCategory = .other) {
        self.name = name
        self.monthlyAmount = monthlyAmount
        self.startDate = startDate
        self.endDate = endDate
        self.categoryRaw = category.rawValue
    }

    var category: CostCategory {
        get { CostCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}

@Model
final class OtherCost {
    var name: String
    var amount: Double
    var date: Date
    var categoryRaw: String
    var notes: String
    var trip: Trip?
    var car: Car?

    init(name: String, amount: Double, date: Date, category: CostCategory = .other, notes: String = "") {
        self.name = name
        self.amount = amount
        self.date = date
        self.categoryRaw = category.rawValue
        self.notes = notes
    }

    var category: CostCategory {
        get { CostCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}

@Model
final class Trip {
    var name: String
    var createdAt: Date
    var car: Car?
    @Relationship(deleteRule: .nullify, inverse: \FuelEntry.trip) var fuelEntries: [FuelEntry] = []
    @Relationship(deleteRule: .nullify, inverse: \OtherCost.trip) var otherCosts: [OtherCost] = []

    init(name: String) {
        self.name = name
        self.createdAt = Date()
    }

    var totalFuelCost: Double {
        fuelEntries.reduce(0) { $0 + $1.totalCost }
    }

    var totalOtherCost: Double {
        otherCosts.reduce(0) { $0 + $1.amount }
    }

    var totalCost: Double { totalFuelCost + totalOtherCost }

    // km span from first to last tagged fuel entry by odometer
    var kmDriven: Double? {
        let sorted = fuelEntries.sorted { $0.date < $1.date }
        guard sorted.count >= 2, let first = sorted.first, let last = sorted.last else { return nil }
        return max(0, last.odometerReading - first.odometerReading)
    }

    var efficiency: Double? {
        guard let km = kmDriven, km > 0 else { return nil }
        let liters = fuelEntries.reduce(0) { $0 + $1.liters }
        return (liters / km) * 100
    }

    var dateRange: (start: Date, end: Date)? {
        let dates = (fuelEntries.map(\.date) + otherCosts.map(\.date)).sorted()
        guard let first = dates.first, let last = dates.last else { return nil }
        return (first, last)
    }
}
