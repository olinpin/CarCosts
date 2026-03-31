import SwiftData
import Foundation

// MARK: - V1 (original schema — all models defined inline so checksums are isolated from global types)

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SchemaV1.Car.self, SchemaV1.FuelEntry.self, SchemaV1.ResaleValueEntry.self, SchemaV1.RecurringCost.self, SchemaV1.OtherCost.self]
    }

    @Model final class Car {
        var name: String = ""
        var purchasePrice: Double = 0
        var purchaseDate: Date = Date()
        var initialOdometer: Double?
        var resalePromptScheduleRaw: String = ""
        var lastResalePromptDate: Date?
        @Relationship(deleteRule: .cascade) var fuelEntries: [SchemaV1.FuelEntry] = []
        @Relationship(deleteRule: .cascade) var resaleValueEntries: [SchemaV1.ResaleValueEntry] = []
        @Relationship(deleteRule: .cascade) var recurringCosts: [SchemaV1.RecurringCost] = []
        @Relationship(deleteRule: .cascade) var otherCosts: [SchemaV1.OtherCost] = []
        init() {}
    }

    @Model final class FuelEntry {
        var date: Date = Date()
        var liters: Double = 0
        var totalCost: Double = 0
        var pricePerLiter: Double = 0
        var odometerReading: Double = 0
        var car: SchemaV1.Car?
        init() {}
    }

    @Model final class ResaleValueEntry {
        var date: Date = Date()
        var value: Double = 0
        var car: SchemaV1.Car?
        init() {}
    }

    @Model final class RecurringCost {
        var name: String = ""
        var monthlyAmount: Double = 0
        var startDate: Date = Date()
        var endDate: Date?
        var categoryRaw: String = ""
        var car: SchemaV1.Car?
        init() {}
    }

    @Model final class OtherCost {
        var name: String = ""
        var amount: Double = 0
        var date: Date = Date()
        var categoryRaw: String = ""
        var notes: String = ""
        var car: SchemaV1.Car?
        init() {}
    }
}

// MARK: - V2 (adds FuelEntry.filledToFull with default true)

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Car.self, FuelEntry.self, ResaleValueEntry.self, RecurringCost.self, OtherCost.self]
    }
}

// MARK: - Migration plan

enum CarCostsMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)]
    }
}
