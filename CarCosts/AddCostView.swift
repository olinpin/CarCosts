import SwiftUI
import SwiftData

struct AddCostView: View {
    let car: Car
    var editingTarget: EditableCostItem? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var amountText = ""
    @State private var date = Date()
    @State private var category: CostCategory = .maintenance
    @State private var notes = ""
    @State private var isRecurring = false
    @State private var monthlyAmountText = ""
    @State private var selectedTrip: Trip?

    private var canSave: Bool {
        let nameOK = !name.trimmingCharacters(in: .whitespaces).isEmpty
        if isRecurring {
            return nameOK && Double(monthlyAmountText.replacingOccurrences(of: ",", with: ".")) != nil
        }
        return nameOK && Double(amountText.replacingOccurrences(of: ",", with: ".")) != nil
    }

    private var isEditing: Bool { editingTarget != nil }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.ccTeal)
                        Text(isEditing ? "Edit Cost" : "Log Cost")
                            .font(.title2.bold())
                            .foregroundStyle(Color.ccTextPrimary)
                    }
                    .padding(.top, 36)

                    VStack(spacing: 14) {
                        // Recurring toggle
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Recurring cost")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.ccTextPrimary)
                                Text("Insurance, road tax, etc.")
                                    .font(.caption)
                                    .foregroundStyle(Color.ccTextSecondary)
                            }
                            Spacer()
                            Toggle("", isOn: $isRecurring)
                                .tint(Color.ccTeal)
                                .disabled(isEditing)
                        }
                        .padding(14)
                        .ccCardSurface(cornerRadius: 14)
                        .opacity(isEditing ? 0.75 : 1)

                        // Name
                        GlassInputField(title: "Name", text: $name, placeholder: isRecurring ? "e.g. Insurance" : "e.g. Tyre change")

                        // Category picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Category")
                                .font(.caption)
                                .foregroundStyle(Color.ccTextSecondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(CostCategory.allCases, id: \.self) { cat in
                                        CategoryChip(category: cat, isSelected: category == cat)
                                            .onTapGesture { category = cat }
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        }

                        if isRecurring {
                            GlassInputField(
                                title: "Monthly amount (EUR)",
                                text: $monthlyAmountText,
                                placeholder: "e.g. 85",
                                keyboardType: .decimalPad
                            )

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Start date")
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
                        } else {
                            GlassInputField(
                                title: "Amount (EUR)",
                                text: $amountText,
                                placeholder: "e.g. 320",
                                keyboardType: .decimalPad
                            )

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

                            // Notes
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Notes (optional)")
                                    .font(.caption)
                                    .foregroundStyle(Color.ccTextSecondary)
                                TextField("e.g. Replaced front tyres", text: $notes)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .ccCardSurface(cornerRadius: 12)
                                    .foregroundStyle(Color.ccTextPrimary)
                            }

                            TripPickerRow(car: car, selectedTrip: $selectedTrip)
                        }
                    }
                    .padding(.horizontal, 24)

                    HStack(spacing: 12) {
                        Button("Cancel") { dismiss() }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .ccCardSurface(cornerRadius: 14)
                            .foregroundStyle(Color.ccTextSecondary)

                        Button(isEditing ? "Update" : "Save") { save() }
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
        .onAppear {
            guard let editingTarget else { return }
            switch editingTarget {
            case .recurring(let cost):
                name = cost.name
                monthlyAmountText = String(format: "%.2f", cost.monthlyAmount)
                date = cost.startDate
                category = cost.category
                isRecurring = true
            case .oneTime(let cost):
                name = cost.name
                amountText = String(format: "%.2f", cost.amount)
                date = cost.date
                category = cost.category
                notes = cost.notes
                selectedTrip = cost.trip
                isRecurring = false
            }
        }
    }

    private func save() {
        if isRecurring {
            guard let monthly = Double(monthlyAmountText.replacingOccurrences(of: ",", with: ".")),
                  !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            if case .recurring(let cost) = editingTarget {
                cost.name = name.trimmingCharacters(in: .whitespaces)
                cost.monthlyAmount = monthly
                cost.startDate = date
                cost.category = category
            } else {
                let cost = RecurringCost(name: name.trimmingCharacters(in: .whitespaces), monthlyAmount: monthly, startDate: date, category: category)
                cost.car = car
                modelContext.insert(cost)
            }
        } else {
            guard let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")),
                  !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            if case .oneTime(let cost) = editingTarget {
                cost.name = name.trimmingCharacters(in: .whitespaces)
                cost.amount = amount
                cost.date = date
                cost.category = category
                cost.notes = notes
                cost.trip = selectedTrip
            } else {
                let cost = OtherCost(name: name.trimmingCharacters(in: .whitespaces), amount: amount, date: date, category: category, notes: notes)
                cost.trip = selectedTrip
                cost.car = car
                modelContext.insert(cost)
            }
        }
        dismiss()
    }
}

enum EditableCostItem: Identifiable {
    case recurring(RecurringCost)
    case oneTime(OtherCost)

    var id: PersistentIdentifier {
        switch self {
        case .recurring(let cost):
            cost.persistentModelID
        case .oneTime(let cost):
            cost.persistentModelID
        }
    }
}

struct CategoryChip: View {
    let category: CostCategory
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.systemImage)
                .font(.caption2)
            Text(category.rawValue)
                .font(.caption)
        }
        .foregroundStyle(isSelected ? Color.ccTextPrimary : Color.ccTextSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .ccCardSurface(cornerRadius: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.ccTeal.opacity(0.7) : Color.clear, lineWidth: 1)
        )
    }
}
