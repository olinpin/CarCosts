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

// MARK: - Design tokens

extension Color {
    /// Warm amber — primary accent (fuel, speed, energy)
    static let ccAmber     = Color(red: 1.00, green: 0.52, blue: 0.08)
    /// Electric teal — secondary accent (total cost, precision)
    static let ccTeal      = Color(red: 0.00, green: 0.88, blue: 0.74)
    /// Ember red — loss / amortization
    static let ccEmber     = Color(red: 0.92, green: 0.22, blue: 0.12)
    /// Mint green — efficiency / good metric
    static let ccMint      = Color(red: 0.30, green: 0.95, blue: 0.55)
    /// Warm cream — primary text on dark glass
    static let ccCream     = Color(red: 1.00, green: 0.96, blue: 0.90)
}

// MARK: - App background

/// The near-black base used for sheet presentation backgrounds (prevents white flash).
let ccBaseColor = Color(red: 0.05, green: 0.04, blue: 0.06)

struct AppBackground: View {
    var body: some View {
        ZStack {
            ccBaseColor.ignoresSafeArea()

            // Amber glow — bottom-centre, main "headlight" light source
            RadialGradient(
                colors: [Color.ccAmber.opacity(0.55), .clear],
                center: .init(x: 0.5, y: 1.1),
                startRadius: 0,
                endRadius: 560
            )
            .ignoresSafeArea()

            // Teal accent — top-left edge, cool contrast
            RadialGradient(
                colors: [Color.ccTeal.opacity(0.32), .clear],
                center: .init(x: -0.05, y: 0.1),
                startRadius: 0,
                endRadius: 420
            )
            .ignoresSafeArea()

            // Ember — upper-right, subtle heat
            RadialGradient(
                colors: [Color.ccEmber.opacity(0.24), .clear],
                center: .init(x: 1.1, y: 0.06),
                startRadius: 0,
                endRadius: 340
            )
            .ignoresSafeArea()
        }
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
