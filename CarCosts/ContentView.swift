import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var cars: [Car]

    var body: some View {
        if let car = cars.first {
            MainTabView(car: car)
        } else {
            OnboardingView()
        }
    }
}

struct MainTabView: View {
    let car: Car

    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "gauge.medium") {
                DashboardView(car: car)
            }
            Tab("Logs", systemImage: "list.bullet") {
                LogsView(car: car)
            }
            Tab("Stats", systemImage: "chart.bar.fill") {
                StatsView(car: car)
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView(car: car)
            }
        }
    }
}
