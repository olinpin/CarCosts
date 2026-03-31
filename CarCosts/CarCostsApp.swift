import SwiftUI
import SwiftData

@main
struct CarCostsApp: App {
    let container: ModelContainer

    init() {
        do {
            let schema = Schema([
                Car.self,
                FuelEntry.self,
                ResaleValueEntry.self,
                RecurringCost.self,
                OtherCost.self
            ])
            // To enable iCloud sync: add CloudKit capability, then use
            // ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            container = try ModelContainer(for: schema)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
