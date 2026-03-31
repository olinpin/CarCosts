import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Number formatting

func formatEUR(_ value: Double) -> String {
    String(format: "€%.2f", value)
}

func formatCostPerKm(_ value: Double) -> String {
    String(format: "€%.3f", value)
}

func formatLiters(_ value: Double) -> String {
    String(format: "%.2fL", value)
}

func formatKm(_ value: Double) -> String {
    if value >= 1000 {
        return String(format: "%.1fk km", value / 1000)
    }
    return String(format: "%.0f km", value)
}

func formatEfficiency(_ value: Double) -> String {
    String(format: "%.1f L/100", value)
}

// MARK: - Period

enum Period: String, CaseIterable {
    case allTime = "All Time"
    case thisMonth = "This Month"
    case custom = "Custom"
}

func dateRange(for period: Period, customStart: Date, customEnd: Date, carPurchaseDate: Date) -> (start: Date, end: Date) {
    switch period {
    case .allTime:
        return (carPurchaseDate, Date())
    case .thisMonth:
        let start = Calendar.current.startOfMonth(for: Date())
        return (start, Date())
    case .custom:
        return (customStart, customEnd)
    }
}

// MARK: - App background

struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.06, blue: 0.18),
                Color(red: 0.08, green: 0.04, blue: 0.22),
                Color(red: 0.04, green: 0.12, blue: 0.28)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Glass input field

struct GlassInputField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
        }
    }
}
