import SwiftUI
import SwiftData

struct SettingsView: View {
    let car: Car
    @Environment(\.modelContext) private var modelContext

    @State private var showAddResale = false
    @State private var resaleEntryToEdit: EditableResaleEntry?
    @State private var showAddRecurring = false
    @State private var recurringCostToEdit: EditableCostItem?
    @State private var showEditCar = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        Text("Settings")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ccTextPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        // Car info
                        carInfoSection

                        // Resale value prompt schedule
                        promptScheduleSection

                        // Resale value history
                        resaleValueSection

                        // Recurring costs
                        recurringCostsSection

                        Spacer(minLength: 100)
                    }
                    .padding(.top)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddResale) {
                AddResaleValueSheet(car: car, onSave: {})
            }
            .sheet(item: $resaleEntryToEdit) { item in
                AddResaleValueSheet(car: car, entryToEdit: item.entry, onSave: {})
            }
            .sheet(item: $recurringCostToEdit) { item in
                AddCostView(car: car, editingTarget: item)
            }
            .sheet(isPresented: $showEditCar) {
                EditCarSheet(car: car)
            }
        }
    }

    // MARK: - Car Info

    private var carInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Car")
                    .font(.headline)
                    .foregroundStyle(Color.ccTextPrimary)
                Spacer()
                Button("Edit") { showEditCar = true }
                    .font(.caption)
                    .foregroundStyle(Color.ccTextSecondary)
            }

            VStack(spacing: 0) {
                SettingsRow(label: "Name", value: car.name)
                Divider().background(.white.opacity(0.08)).padding(.horizontal, 16)
                SettingsRow(label: "Purchase price", value: formatEUR(car.purchasePrice))
                Divider().background(.white.opacity(0.08)).padding(.horizontal, 16)
                SettingsRow(label: "Purchase date", value: car.purchaseDate.formatted(date: .long, time: .omitted))
                if let initialOdometer = car.initialOdometer {
                    Divider().background(.white.opacity(0.08)).padding(.horizontal, 16)
                    SettingsRow(label: "Initial odometer", value: "\(Int(initialOdometer).formatted()) km")
                }
                if let odometer = car.latestOdometer, !car.fuelEntries.isEmpty {
                    Divider().background(.white.opacity(0.08)).padding(.horizontal, 16)
                    SettingsRow(label: "Current odometer", value: "\(Int(odometer).formatted()) km")
                }
                if let resale = car.currentResaleValue {
                    Divider().background(.white.opacity(0.08)).padding(.horizontal, 16)
                    SettingsRow(label: "Latest resale value", value: formatEUR(resale))
                }
                if let amort = CarCalculator(car: car).amortizationPerKm {
                    Divider().background(.white.opacity(0.08)).padding(.horizontal, 16)
                    SettingsRow(label: "Amortization rate", value: "\(formatCostPerKm(amort))/km")
                }
            }
            .ccCardSurface(cornerRadius: 18)
        }
        .padding(.horizontal)
    }

    // MARK: - Prompt Schedule

    private var promptScheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resale Value Reminder")
                .font(.headline)
                .foregroundStyle(Color.ccTextPrimary)

            VStack(spacing: 0) {
                ForEach(PromptSchedule.allCases, id: \.self) { schedule in
                    HStack {
                        Text(schedule.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(Color.ccTextPrimary)
                        Spacer()
                        if car.promptSchedule == schedule {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.ccTeal)
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        car.promptSchedule = schedule
                    }
                    if schedule != PromptSchedule.allCases.last {
                        Divider().background(.white.opacity(0.08)).padding(.horizontal, 16)
                    }
                }
            }
            .ccCardSurface(cornerRadius: 18)
        }
        .padding(.horizontal)
    }

    // MARK: - Resale Values

    private var resaleValueSection: some View {
        let sorted = car.resaleValueEntries.sorted { $0.date > $1.date }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Resale Value History")
                    .font(.headline)
                    .foregroundStyle(Color.ccTextPrimary)
                Spacer()
                Button {
                    showAddResale = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.ccTextSecondary)
                }
            }

            if sorted.isEmpty {
                Text("No resale values recorded yet — add one to enable amortization tracking")
                    .font(.caption)
                    .foregroundStyle(Color.ccTextSecondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .ccCardSurface(cornerRadius: 18)
            } else {
                List {
                    ForEach(Array(sorted.enumerated()), id: \.element.persistentModelID) { idx, entry in
                        ResaleValueRow(entry: entry, isLatest: idx == 0)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                resaleEntryToEdit = EditableResaleEntry(entry: entry)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    modelContext.delete(entry)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(Color.white.opacity(0.10))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.ccSurfaceStroke, lineWidth: 1)
                )
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.ccSurface)
                )
                .frame(height: CGFloat(sorted.count) * 58 + 2)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Recurring Costs

    private var recurringCostsSection: some View {
        let sorted = car.recurringCosts.sorted { $0.startDate > $1.startDate }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recurring Costs")
                    .font(.headline)
                    .foregroundStyle(Color.ccTextPrimary)
                Spacer()
                NavigationLink {
                    AddCostViewWrapper(car: car, isRecurring: true)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.ccTextSecondary)
                }
            }

            if sorted.isEmpty {
                Text("No recurring costs yet — add insurance, road tax, etc.")
                    .font(.caption)
                    .foregroundStyle(Color.ccTextSecondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .ccCardSurface(cornerRadius: 18)
            } else {
                List {
                    ForEach(sorted, id: \.persistentModelID) { cost in
                        RecurringCostSettingsRow(cost: cost)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                recurringCostToEdit = .recurring(cost)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    modelContext.delete(cost)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(Color.white.opacity(0.10))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.ccSurfaceStroke, lineWidth: 1)
                )
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.ccSurface)
                )
                .frame(height: CGFloat(sorted.count) * 58 + 2)
            }
        }
        .padding(.horizontal)
    }
}

private struct EditableResaleEntry: Identifiable {
    let entry: ResaleValueEntry
    var id: PersistentIdentifier { entry.persistentModelID }
}

private struct ResaleValueRow: View {
    let entry: ResaleValueEntry
    let isLatest: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(formatEUR(entry.value))
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.ccTextPrimary)
                Text(entry.date.formatted(date: .long, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(Color.ccTextMuted)
            }
            Spacer()
            if isLatest {
                Text("Latest")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.ccSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.ccTeal.opacity(0.35), lineWidth: 1)
                    )
                    .foregroundStyle(Color.ccTeal)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

private struct RecurringCostSettingsRow: View {
    let cost: RecurringCost

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: cost.category.systemImage)
                .font(.callout)
                .foregroundStyle(Color.ccTeal.opacity(0.85))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(cost.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.ccTextPrimary)
                Text(cost.category.rawValue + " · from \(cost.startDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundStyle(Color.ccTextMuted)
            }
            Spacer()
            Text("\(formatEUR(cost.monthlyAmount))/mo")
                .font(.subheadline.bold())
                .foregroundStyle(Color.ccTextPrimary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.ccTextSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(Color.ccTextPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
    }
}

// MARK: - Edit Car Sheet

struct EditCarSheet: View {
    let car: Car
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var priceText: String
    @State private var initialOdometerText: String
    @State private var purchaseDate: Date

    init(car: Car) {
        self.car = car
        _name = State(initialValue: car.name)
        _priceText = State(initialValue: String(format: "%.2f", car.purchasePrice))
        _initialOdometerText = State(initialValue: car.initialOdometer.map { String(Int($0)) } ?? "")
        _purchaseDate = State(initialValue: car.purchaseDate)
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 24) {
                Text("Edit Car")
                    .font(.title2.bold())
                    .foregroundStyle(Color.ccTextPrimary)
                    .padding(.top, 40)

                VStack(spacing: 14) {
                    GlassInputField(title: "Car name", text: $name, placeholder: "e.g. VW Golf")
                    GlassInputField(title: "Purchase price (EUR)", text: $priceText, placeholder: "e.g. 25000", keyboardType: .decimalPad)
                    GlassInputField(title: "Initial odometer (km)", text: $initialOdometerText, placeholder: "e.g. 84200", keyboardType: .numberPad)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Purchase date")
                            .font(.caption)
                            .foregroundStyle(Color.ccTextSecondary)
                        DatePicker("", selection: $purchaseDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .ccCardSurface(cornerRadius: 12)
                    }
                }
                .padding(.horizontal, 24)

                HStack(spacing: 12) {
                    Button("Cancel") { dismiss() }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .ccCardSurface(cornerRadius: 14)
                        .foregroundStyle(Color.ccTextSecondary)

                    Button("Save") {
                        car.name = name.trimmingCharacters(in: .whitespaces)
                        if let price = Double(priceText.replacingOccurrences(of: ",", with: ".")) {
                            car.purchasePrice = price
                        }
                        car.initialOdometer = Double(initialOdometerText.replacingOccurrences(of: ",", with: "."))
                        car.purchaseDate = purchaseDate
                        dismiss()
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .ccCardSurface(cornerRadius: 14)
                    .foregroundStyle(Color.ccTextPrimary)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .presentationBackground(ccBaseColor)
    }
}

// MARK: - Add Cost Wrapper (for direct recurring cost entry from settings)

struct AddCostViewWrapper: View {
    let car: Car
    let isRecurring: Bool

    var body: some View {
        AddCostView(car: car)
    }
}
