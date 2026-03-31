import SwiftUI
import SwiftData

// Top-level so FuelFieldRow can reference it for the focus binding
enum FuelField: Hashable, CaseIterable { case liters, total, ppl }

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
    @State private var filledToFull = true
    @State private var selectedTrip: Trip?

    // Which field was last auto-filled; nil means all values are user-provided
    @State private var calculatedField: FuelField?
    // Guard against onChange firing when we programmatically set a value
    @State private var isApplyingCalculatedValue = false

    @FocusState private var focusedField: FuelField?

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
                            placeholder: "e.g. 42.5",
                            focus: $focusedField,
                            fieldId: .liters
                        )

                        FuelFieldRow(
                            title: "Total cost (EUR)",
                            text: $totalCostText,
                            isCalculated: calculatedField == .total,
                            placeholder: "e.g. 67.20",
                            focus: $focusedField,
                            fieldId: .total
                        )

                        FuelFieldRow(
                            title: "Price per litre (EUR/L)",
                            text: $pricePerLiterText,
                            isCalculated: calculatedField == .ppl,
                            placeholder: "e.g. 1.599",
                            focus: $focusedField,
                            fieldId: .ppl
                        )

                        Divider()
                            .background(.white.opacity(0.15))
                            .padding(.vertical, 4)

                        Toggle(isOn: $filledToFull) {
                            Text("Filled to full")
                                .font(.subheadline)
                                .foregroundStyle(Color.ccTextPrimary)
                        }
                        .tint(Color.ccAmber)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .ccCardSurface(cornerRadius: 12)

                        TripPickerRow(car: car, selectedTrip: $selectedTrip)
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
            .onTapGesture { focusedField = nil }
        }
        .presentationBackground(ccBaseColor)
        // Odometer formatting
        .onChange(of: odometerText) { _, newValue in
            guard !isApplyingCalculatedValue else { return }
            formatOdometerInput(newValue)
        }
        // Detect user manually editing the auto-calculated field — it becomes theirs
        .onChange(of: litersText) { _, _ in
            guard !isApplyingCalculatedValue, calculatedField == .liters else { return }
            calculatedField = nil
        }
        .onChange(of: totalCostText) { _, _ in
            guard !isApplyingCalculatedValue, calculatedField == .total else { return }
            calculatedField = nil
        }
        .onChange(of: pricePerLiterText) { _, _ in
            guard !isApplyingCalculatedValue, calculatedField == .ppl else { return }
            calculatedField = nil
        }
        // Trigger calculation when the user finishes a field (focus moves away)
        .onChange(of: focusedField) { _, _ in
            recalculateIfReady()
        }
        .onAppear {
            guard let entryToEdit else { return }
            litersText = String(format: "%.3f", entryToEdit.liters)
            totalCostText = String(format: "%.2f", entryToEdit.totalCost)
            pricePerLiterText = String(format: "%.4f", entryToEdit.pricePerLiter)
            odometerText = formatOdometer(entryToEdit.odometerReading)
            date = entryToEdit.date
            filledToFull = entryToEdit.filledToFull
            selectedTrip = entryToEdit.trip
        }
    }

    // MARK: - Calculation

    private func recalculateIfReady() {
        let l = decimalValue(from: litersText)
        let t = decimalValue(from: totalCostText)
        let p = decimalValue(from: pricePerLiterText)

        func hasValue(_ f: FuelField) -> Bool {
            switch f {
            case .liters: return l != nil
            case .total:  return t != nil
            case .ppl:    return p != nil
            }
        }

        // Fields the user has manually filled (everything except the auto-calculated one)
        let manualFields = FuelField.allCases.filter { $0 != calculatedField && hasValue($0) }

        guard manualFields.count == 2 else {
            // Lost one of the inputs — clear the stale calculated value
            if let cf = calculatedField, manualFields.count < 2 {
                setField(cf, nil)
                calculatedField = nil
            }
            return
        }

        // Which field to fill in: prefer the previously calculated one, else the empty one
        let toCalc: FuelField
        if let cf = calculatedField {
            toCalc = cf
        } else if let empty = FuelField.allCases.first(where: { !hasValue($0) }) {
            toCalc = empty
        } else {
            return // all three are manually filled — nothing to do
        }

        // Never fill a field the user is actively typing in
        guard toCalc != focusedField else { return }

        switch toCalc {
        case .liters:
            guard let t, let p, p > 0 else { return }
            setField(.liters, t / p)
        case .total:
            guard let l, let p else { return }
            setField(.total, l * p)
        case .ppl:
            guard let l, let t, l > 0 else { return }
            setField(.ppl, t / l)
        }
        calculatedField = toCalc
    }

    private func setField(_ field: FuelField, _ value: Double?) {
        isApplyingCalculatedValue = true
        switch field {
        case .liters: litersText      = value.map { String(format: "%.3f", $0) } ?? ""
        case .total:  totalCostText   = value.map { String(format: "%.2f", $0) } ?? ""
        case .ppl:    pricePerLiterText = value.map { String(format: "%.4f", $0) } ?? ""
        }
        isApplyingCalculatedValue = false
    }

    // MARK: - Helpers

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
            entryToEdit.filledToFull = filledToFull
            entryToEdit.trip = selectedTrip
        } else {
            let entry = FuelEntry(date: date, liters: liters, totalCost: total, pricePerLiter: ppl, odometerReading: odometer, filledToFull: filledToFull)
            entry.trip = selectedTrip
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
    var focus: FocusState<FuelField?>.Binding
    let fieldId: FuelField

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
                .focused(focus, equals: fieldId)
        }
    }
}
