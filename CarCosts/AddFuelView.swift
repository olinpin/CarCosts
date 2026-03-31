import SwiftUI
import SwiftData

struct AddFuelView: View {
    let car: Car
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var litersText = ""
    @State private var totalCostText = ""
    @State private var pricePerLiterText = ""
    @State private var odometerText = ""

    // Track which two fields are "user-entered" to auto-fill the third
    @State private var litersLocked = false
    @State private var totalLocked = false
    @State private var pplLocked = false

    private var prefillOdometer: String {
        car.latestOdometer.map { String(Int($0 + 1)) } ?? ""
    }

    private var canSave: Bool {
        guard let liters = Double(litersText.replacingOccurrences(of: ",", with: ".")),
              let total = Double(totalCostText.replacingOccurrences(of: ",", with: ".")),
              let _ = Double(pricePerLiterText.replacingOccurrences(of: ",", with: ".")),
              let _ = Double(odometerText.replacingOccurrences(of: ",", with: ".")),
              liters > 0, total > 0 else { return false }
        return true
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 6) {
                        Image(systemName: "fuelpump.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.cyan)
                        Text("Log Fill-Up")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 36)

                    VStack(spacing: 14) {
                        // Date
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Date")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                            DatePicker("", selection: $date, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                        }

                        // Odometer
                        GlassInputField(
                            title: "Odometer reading (km)",
                            text: $odometerText,
                            placeholder: prefillOdometer.isEmpty ? "e.g. 45230" : prefillOdometer,
                            keyboardType: .numberPad
                        )

                        Divider()
                            .background(.white.opacity(0.15))
                            .padding(.vertical, 4)

                        Text("Enter any two — the third is calculated automatically")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(maxWidth: .infinity, alignment: .center)

                        // Fuel trio
                        FuelFieldRow(
                            title: "Litres",
                            text: $litersText,
                            isLocked: litersLocked,
                            placeholder: "e.g. 42.5"
                        )
                        .onChange(of: litersText) { _, _ in recalculate(changed: .liters) }

                        FuelFieldRow(
                            title: "Total cost (EUR)",
                            text: $totalCostText,
                            isLocked: totalLocked,
                            placeholder: "e.g. 67.20"
                        )
                        .onChange(of: totalCostText) { _, _ in recalculate(changed: .total) }

                        FuelFieldRow(
                            title: "Price per litre (EUR/L)",
                            text: $pricePerLiterText,
                            isLocked: pplLocked,
                            placeholder: "e.g. 1.599"
                        )
                        .onChange(of: pricePerLiterText) { _, _ in recalculate(changed: .ppl) }
                    }
                    .padding(.horizontal, 24)

                    HStack(spacing: 12) {
                        Button("Cancel") { dismiss() }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white.opacity(0.7))

                        Button("Save") { saveFuel() }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                            .disabled(!canSave)
                            .opacity(canSave ? 1 : 0.4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private enum FuelField { case liters, total, ppl }

    private func recalculate(changed: FuelField) {
        let l = Double(litersText.replacingOccurrences(of: ",", with: "."))
        let t = Double(totalCostText.replacingOccurrences(of: ",", with: "."))
        let p = Double(pricePerLiterText.replacingOccurrences(of: ",", with: "."))

        switch changed {
        case .liters:
            litersLocked = true
            if let l, let t, t > 0 { setPPL(t / l); pplLocked = false }
            else if let l, let p { setTotal(l * p); totalLocked = false }
        case .total:
            totalLocked = true
            if let l, let t, l > 0 { setPPL(t / l); pplLocked = false }
            else if let t, let p, p > 0 { setLiters(t / p); litersLocked = false }
        case .ppl:
            pplLocked = true
            if let l, let p { setTotal(l * p); totalLocked = false }
            else if let t, let p, p > 0 { setLiters(t / p); litersLocked = false }
        }
    }

    private func setLiters(_ v: Double) { litersText = String(format: "%.3f", v) }
    private func setTotal(_ v: Double) { totalCostText = String(format: "%.2f", v) }
    private func setPPL(_ v: Double) { pricePerLiterText = String(format: "%.4f", v) }

    private func saveFuel() {
        guard let liters = Double(litersText.replacingOccurrences(of: ",", with: ".")),
              let total = Double(totalCostText.replacingOccurrences(of: ",", with: ".")),
              let ppl = Double(pricePerLiterText.replacingOccurrences(of: ",", with: ".")),
              let odometer = Double(odometerText.replacingOccurrences(of: ",", with: ".")) else { return }

        let entry = FuelEntry(date: date, liters: liters, totalCost: total, pricePerLiter: ppl, odometerReading: odometer)
        entry.car = car
        modelContext.insert(entry)
        dismiss()
    }
}

struct FuelFieldRow: View {
    let title: String
    @Binding var text: String
    let isLocked: Bool
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                if isLocked {
                    Spacer()
                    Text("calculated")
                        .font(.caption2)
                        .foregroundStyle(.cyan.opacity(0.7))
                }
            }
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(isLocked ? .white.opacity(0.55) : .white)
                .disabled(false)
        }
    }
}
