import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

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
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, migrationPlan: CarCostsMigrationPlan.self, configurations: config)
            configureTabBarAppearance()
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

    private func configureTabBarAppearance() {
        #if canImport(UIKit)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(ccBaseColor.opacity(0.98))
        appearance.shadowColor = UIColor(Color.white.opacity(0.08))

        let selectedColor = UIColor(Color.ccAmber)
        let normalColor = UIColor(Color.ccTextMuted)

        let stacked = appearance.stackedLayoutAppearance
        stacked.selected.iconColor = selectedColor
        stacked.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        stacked.normal.iconColor = normalColor
        stacked.normal.titleTextAttributes = [.foregroundColor: normalColor]

        let inline = appearance.inlineLayoutAppearance
        inline.selected.iconColor = selectedColor
        inline.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        inline.normal.iconColor = normalColor
        inline.normal.titleTextAttributes = [.foregroundColor: normalColor]

        let compact = appearance.compactInlineLayoutAppearance
        compact.selected.iconColor = selectedColor
        compact.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        compact.normal.iconColor = normalColor
        compact.normal.titleTextAttributes = [.foregroundColor: normalColor]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().unselectedItemTintColor = normalColor
        #endif
    }
}
