import SwiftUI
import SwiftData

// MARK: - Trip Picker Row (used in AddFuelView / AddCostView)

struct TripPickerRow: View {
    let car: Car
    @Binding var selectedTrip: Trip?
    @State private var showPicker = false

    var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trip")
                        .font(.caption)
                        .foregroundStyle(Color.ccTextSecondary)
                    Text(selectedTrip?.name ?? "None")
                        .font(.subheadline)
                        .foregroundStyle(selectedTrip != nil ? Color.ccTextPrimary : Color.ccTextMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.ccTextMuted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .ccCardSurface(cornerRadius: 12)
        }
        .sheet(isPresented: $showPicker) {
            TripPickerSheet(car: car, selectedTrip: $selectedTrip)
        }
    }
}

// MARK: - Trip Picker Sheet

struct TripPickerSheet: View {
    let car: Car
    @Binding var selectedTrip: Trip?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showNewTripAlert = false
    @State private var newTripName = ""

    private var sortedTrips: [Trip] {
        car.trips.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Select Trip")
                        .font(.headline)
                        .foregroundStyle(Color.ccTextPrimary)
                    Spacer()
                    Button {
                        showNewTripAlert = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.ccTeal)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 12)

                List {
                    // None option
                    Button {
                        selectedTrip = nil
                        dismiss()
                    } label: {
                        HStack {
                            Text("None")
                                .foregroundStyle(Color.ccTextSecondary)
                            Spacer()
                            if selectedTrip == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.ccTeal)
                                    .font(.caption.bold())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Color.white.opacity(0.10))

                    ForEach(sortedTrips, id: \.persistentModelID) { trip in
                        Button {
                            selectedTrip = trip
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(trip.name)
                                        .foregroundStyle(Color.ccTextPrimary)
                                    if let range = trip.dateRange {
                                        Text("\(range.start.formatted(date: .abbreviated, time: .omitted)) – \(range.end.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.caption2)
                                            .foregroundStyle(Color.ccTextMuted)
                                    } else {
                                        Text("No entries yet")
                                            .font(.caption2)
                                            .foregroundStyle(Color.ccTextMuted)
                                    }
                                }
                                Spacer()
                                if selectedTrip?.persistentModelID == trip.persistentModelID {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.ccTeal)
                                        .font(.caption.bold())
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(Color.white.opacity(0.10))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .presentationBackground(ccBaseColor)
        .presentationDetents([.medium, .large])
        .alert("New Trip", isPresented: $showNewTripAlert) {
            TextField("e.g. Spain Vacation", text: $newTripName)
            Button("Create") {
                let trimmed = newTripName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                let trip = Trip(name: trimmed)
                trip.car = car
                modelContext.insert(trip)
                selectedTrip = trip
                newTripName = ""
                dismiss()
            }
            .disabled(newTripName.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Cancel", role: .cancel) { newTripName = "" }
        }
    }
}

// MARK: - Trip Row (used in LogsView trips tab)

struct TripRow: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "map.fill")
                .font(.callout)
                .foregroundStyle(Color.purple.opacity(0.85))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(trip.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                if let range = trip.dateRange {
                    Text("\(range.start.formatted(date: .abbreviated, time: .omitted)) – \(range.end.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundStyle(Color.ccTextMuted)
                } else {
                    Text("No entries yet")
                        .font(.caption2)
                        .foregroundStyle(Color.ccTextMuted)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(formatEUR(trip.totalCost))
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                let count = trip.fuelEntries.count + trip.otherCosts.count
                Text("\(count) \(count == 1 ? "entry" : "entries")")
                    .font(.caption2)
                    .foregroundStyle(Color.ccTextMuted)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

// MARK: - Trip Detail View

struct TripDetailView: View {
    @Bindable var trip: Trip
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isEditingName = false
    @State private var editedName = ""

    private var sortedFuel: [FuelEntry] {
        trip.fuelEntries.sorted { $0.date > $1.date }
    }

    private var sortedCosts: [OtherCost] {
        trip.otherCosts.sorted { $0.date > $1.date }
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 20) {
                    // Trip name header
                    HStack {
                        if isEditingName {
                            TextField("Trip name", text: $editedName)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ccTextPrimary)
                                .onSubmit {
                                    let trimmed = editedName.trimmingCharacters(in: .whitespaces)
                                    if !trimmed.isEmpty { trip.name = trimmed }
                                    isEditingName = false
                                }
                        } else {
                            Text(trip.name)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ccTextPrimary)
                        }
                        Spacer()
                        Button {
                            if isEditingName {
                                let trimmed = editedName.trimmingCharacters(in: .whitespaces)
                                if !trimmed.isEmpty { trip.name = trimmed }
                                isEditingName = false
                            } else {
                                editedName = trip.name
                                isEditingName = true
                            }
                        } label: {
                            Text(isEditingName ? "Done" : "Rename")
                                .font(.caption)
                                .foregroundStyle(Color.ccTeal)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Stats
                    tripStats
                        .padding(.horizontal)

                    // Fuel entries
                    if !sortedFuel.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Fill-Ups")
                                .font(.caption)
                                .foregroundStyle(Color.ccTextSecondary)
                                .padding(.horizontal)

                            VStack(spacing: 0) {
                                ForEach(Array(sortedFuel.enumerated()), id: \.element.persistentModelID) { idx, entry in
                                    let prevEntry: FuelEntry? = idx < sortedFuel.count - 1 ? sortedFuel[idx + 1] : nil
                                    FuelEntryRow(entry: entry, prev: prevEntry)
                                    if idx < sortedFuel.count - 1 {
                                        Divider().background(Color.white.opacity(0.08)).padding(.leading, 56)
                                    }
                                }
                            }
                            .ccCardSurface(cornerRadius: 16)
                        }
                        .padding(.horizontal)
                    }

                    // One-time costs
                    if !sortedCosts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Costs")
                                .font(.caption)
                                .foregroundStyle(Color.ccTextSecondary)
                                .padding(.horizontal)

                            VStack(spacing: 0) {
                                ForEach(Array(sortedCosts.enumerated()), id: \.element.persistentModelID) { idx, cost in
                                    OtherCostRow(cost: cost)
                                    if idx < sortedCosts.count - 1 {
                                        Divider().background(Color.white.opacity(0.08)).padding(.leading, 56)
                                    }
                                }
                            }
                            .ccCardSurface(cornerRadius: 16)
                        }
                        .padding(.horizontal)
                    }

                    if sortedFuel.isEmpty && sortedCosts.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "map")
                                .font(.largeTitle)
                                .foregroundStyle(Color.ccTextMuted)
                            Text("No entries tagged to this trip yet")
                                .font(.subheadline)
                                .foregroundStyle(Color.ccTextSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                        .ccCardSurface(cornerRadius: 18)
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(false)
    }

    private var tripStats: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            TripStatTile(label: "Distance", value: trip.kmDriven.map { formatKm($0) } ?? "--", color: .ccTeal)
            TripStatTile(label: "Fuel cost", value: formatEUR(trip.totalFuelCost), color: .ccAmber)
            TripStatTile(label: "Other costs", value: formatEUR(trip.totalOtherCost), color: .ccAmber)
            TripStatTile(label: "Efficiency", value: trip.efficiency.map { formatEfficiency($0) } ?? "--", color: .ccTeal)
        }
    }
}

private struct TripStatTile: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.ccTextSecondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .ccCardSurface(cornerRadius: 12)
    }
}

// MARK: - Trip FAB

struct LogTripFAB: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("New Trip")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Color.ccTextPrimary)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(Color.purple.opacity(0.75))
                    .shadow(color: Color.purple.opacity(0.35), radius: 16, x: 0, y: 6)
            )
        }
    }
}

// MARK: - Trip tag badge (reusable)

struct TripBadge: View {
    let name: String

    var body: some View {
        Text(name)
            .font(.caption2)
            .foregroundStyle(Color.purple.opacity(0.9))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.purple.opacity(0.18))
            .clipShape(Capsule())
    }
}
