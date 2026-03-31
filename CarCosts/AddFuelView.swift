import SwiftUI
import SwiftData

struct AddFuelView: View {
    let car: Car
    var entryToEdit: FuelEntry? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var litersText = ""
    @State private var totalCostText = ""
    @State private var pricePerLiterText = ""
    @State private var odometerText = ""
    @State private var calculatedField: FuelField?
    @State private var isApplyingCalculatedValue = false
    @State private var userEditedFields: Set<FuelField> = []

    private var prefillOdometer: String {
        car.latestOdometer.map { formatOdometer($0 + 1) } ?? ""
    }

    private var canSave: Bool {
        guard let liters = decimalValue(from: litersText),
              let total = decimalValue(from: totalCostText),
              let _ = decimalValue(from: pricePerLiterText),
              let _ = odometerValue(from: odometerText),
              liters > 0, total > 0 else { return false }
        return true
    }

    private var isEditing: Bool { entryToEdit != nil }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 6) {
                        Image(systemName: "fuelpump.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.ccAmber)
                        Text(isEditing ? "Edit Fill-Up" : "Log Fill-Up")
                            .font(.title2.bold())
                            .foregroundStyle(Color.ccTextPrimary)
                    }
                    .padding(.top, 36)

                    VStack(spacing: 14) {
                        // Date
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Date")
                                .font(.caption)
                                .foregroundStyle(Color.ccTextSecondary)
                            DatePicker("", selection: $date, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .ccCardSurface(cornerRadius: 12)
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
                            .foregroundStyle(Color.ccTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)

                        // Fuel trio
                        FuelFieldRow(
                            title: "Litres",
                            text: $litersText,
                            isCalculated: calculatedField == .liters,
                            placeholder: "e.g. 42.5"
                        )
                        .onChange(of: litersText) { _, _ in handleUserChange(to: .liters) }

                        FuelFieldRow(
                            title: "Total cost (EUR)",
                            text: $totalCostText,
                            isCalculated: calculatedField == .total,
                            placeholder: "e.g. 67.20"
                        )
                        .onChange(of: totalCostText) { _, _ in handleUserChange(to: .total) }

                        FuelFieldRow(
                            title: "Price per litre (EUR/L)",
                            text: $pricePerLiterText,
                            isCalculated: calculatedField == .ppl,
                            placeholder: "e.g. 1.599"
                        )
                        .onChange(of: pricePerLiterText) { _, _ in handleUserChange(to: .ppl) }
                    }
                    .padding(.horizontal, 24)

                    HStack(spacing: 12) {
                        Button("Cancel") { dismiss() }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .ccCardSurface(cornerRadius: 14)
                            .foregroundStyle(Color.ccTextSecondary)

                        Button(isEditing ? "Update" : "Save") { saveFuel() }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .ccCardSurface(cornerRadius: 14)
                            .foregroundStyle(Color.ccTextPrimary)
                            .disabled(!canSave)
                            .opacity(canSave ? 1 : 0.4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .presentationBackground(ccBaseColor)
        .onChange(of: odometerText) { _, newValue in
            guard !isApplyingCalculatedValue else { return }
            formatOdometerInput(newValue)
        }
        .onAppear {
            guard let entryToEdit else { return }
            litersText = String(format: "%.3f", entryToEdit.liters)
            totalCostText = String(format: "%.2f", entryToEdit.totalCost)
            pricePerLiterText = String(format: "%.4f", entryToEdit.pricePerLiter)
            odometerText = formatOdometer(entryToEdit.odometerReading)
            date = entryToEdit.date
            userEditedFields = [.liters, .total, .ppl]
        }
    }

    private enum FuelField: CaseIterable { case liters, total, ppl }

    private func handleUserChange(to field: FuelField) {
        guard !isApplyingCalculatedValue else { return }

        if fieldText(for: field).isEmpty {
            userEditedFields.remove(field)
        } else {
            userEditedFields.insert(field)
        }

        if calculatedField == field {
            calculatedField = nil
        }

        recalculate()
    }

    private func recalculate() {
        let liters = decimalValue(from: litersText)
        let total = decimalValue(from: totalCostText)
        let pricePerLiter = decimalValue(from: pricePerLiterText)

        let validFields: [FuelField] = [
            liters.map { _ in FuelField.liters },
            total.map { _ in FuelField.total },
            pricePerLiter.map { _ in FuelField.ppl }
        ].compactMap { $0 }

        let derivedCandidate = calculatedField.flatMap { userEditedFields.contains($0) ? nil : $0 }
        let eligibleMissingFields = FuelField.allCases.filter {
            !userEditedFields.contains($0) && (!validFields.contains($0) || $0 == derivedCandidate)
        }

        guard (validFields.count == 2 || (validFields.count == 3 && derivedCandidate != nil)), eligibleMissingFields.count == 1 else {
            calculatedField = nil
            return
        }

        let missingField = eligibleMissingFields[0]

        if missingField == .liters, let total, let pricePerLiter, pricePerLiter > 0 {
            calculatedField = .liters
            setLiters(total / pricePerLiter)
        } else if missingField == .total, let liters, let pricePerLiter {
            calculatedField = .total
            setTotal(liters * pricePerLiter)
        } else if missingField == .ppl, let liters, let total, liters > 0 {
            calculatedField = .ppl
            setPPL(total / liters)
        } else {
            calculatedField = nil
        }
    }

    private func setLiters(_ v: Double) {
        isApplyingCalculatedValue = true
        litersText = String(format: "%.3f", v)
        isApplyingCalculatedValue = false
    }

    private func setTotal(_ v: Double) {
        isApplyingCalculatedValue = true
        totalCostText = String(format: "%.2f", v)
        isApplyingCalculatedValue = false
    }

    private func setPPL(_ v: Double) {
        isApplyingCalculatedValue = true
        pricePerLiterText = String(format: "%.4f", v)
        isApplyingCalculatedValue = false
    }

    private func clear(field: FuelField) {
        isApplyingCalculatedValue = true
        switch field {
        case .liters:
            litersText = ""
        case .total:
            totalCostText = ""
        case .ppl:
            pricePerLiterText = ""
        }
        isApplyingCalculatedValue = false
    }

    private func fieldText(for field: FuelField) -> String {
        switch field {
        case .liters:
            litersText
        case .total:
            totalCostText
        case .ppl:
            pricePerLiterText
        }
    }

    private func decimalValue(from text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }

    private func odometerValue(from text: String) -> Double? {
        let digits = text.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        return Double(digits)
    }

    private func formatOdometerInput(_ text: String) {
        let digits = text.filter(\.isNumber)
        guard !digits.isEmpty else {
            if odometerText != "" {
                isApplyingCalculatedValue = true
                odometerText = ""
                isApplyingCalculatedValue = false
            }
            return
        }

        guard let value = Double(digits) else { return }
        let formatted = formatOdometer(value)
        guard formatted != odometerText else { return }

        isApplyingCalculatedValue = true
        odometerText = formatted
        isApplyingCalculatedValue = false
    }

    private func saveFuel() {
        guard let liters = decimalValue(from: litersText),
              let total = decimalValue(from: totalCostText),
              let ppl = decimalValue(from: pricePerLiterText),
              let odometer = odometerValue(from: odometerText) else { return }

        if let entryToEdit {
            entryToEdit.date = date
            entryToEdit.liters = liters
            entryToEdit.totalCost = total
            entryToEdit.pricePerLiter = ppl
            entryToEdit.odometerReading = odometer
        } else {
            let entry = FuelEntry(date: date, liters: liters, totalCost: total, pricePerLiter: ppl, odometerReading: odometer)
            entry.car = car
            modelContext.insert(entry)
        }
        dismiss()
    }
}

struct FuelFieldRow: View {
    let title: String
    @Binding var text: String
    let isCalculated: Bool
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.ccTextSecondary)
                if isCalculated {
                    Spacer()
                    Text("calculated")
                        .font(.caption2)
                        .foregroundStyle(Color.ccTeal.opacity(0.8))
                }
            }
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .ccCardSurface(cornerRadius: 12)
                .foregroundStyle(isCalculated ? Color.ccTextSecondary : Color.ccTextPrimary)
                .disabled(false)
        }
    }
}
