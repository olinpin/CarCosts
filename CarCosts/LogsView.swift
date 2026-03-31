import SwiftUI
import SwiftData

struct LogsView: View {
    let car: Car
    @Environment(\.modelContext) private var modelContext

    @State private var showFuelLog = false
    @State private var showCostLog = false
    @State private var showNewTrip = false
    @State private var newTripName = ""
    @State private var fuelEntryToEdit: EditableFuelEntry?
    @State private var costEntryToEdit: EditableCostItem?
    @State private var logTab: LogTab = .fuel

    enum LogTab: String, CaseIterable { case fuel = "Fuel", costs = "Costs", trips = "Trips" }

    private var sortedFuel: [FuelEntry] {
        car.fuelEntries.sorted { $0.date > $1.date }
    }

    private var sortedCosts: [OtherCost] {
        car.otherCosts.sorted { $0.date > $1.date }
    }

    private var sortedRecurring: [RecurringCost] {
        car.recurringCosts.sorted { $0.startDate > $1.startDate }
    }

    private var sortedTrips: [Trip] {
        car.trips.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Logs")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ccTextPrimary)
                        Spacer()
                        Button {
                            if logTab == .fuel { showFuelLog = true }
                            else if logTab == .costs { showCostLog = true }
                            else { showNewTrip = true }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.ccTextPrimary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    
                    // Segment
                    Picker("Log type", selection: $logTab) {
                        ForEach(LogTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .colorScheme(.dark)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                    
                    if logTab == .fuel {
                        fuelSection
                    } else if logTab == .costs {
                        costsSection
                    } else {
                        tripsSection
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .navigationBarHidden(true)
            .safeAreaInset(edge: .bottom) {
                if logTab == .fuel {
                    LogFuelFAB { showFuelLog = true }
                        .padding(.bottom, 8)
                } else if logTab == .costs {
                    LogCostFAB { showCostLog = true }
                        .padding(.bottom, 8)
                } else {
                    LogTripFAB { showNewTrip = true }
                        .padding(.bottom, 8)
                }
            }
            .sheet(isPresented: $showFuelLog) {
                AddFuelView(car: car)
            }
            .alert("New Trip", isPresented: $showNewTrip) {
                TextField("e.g. Spain Vacation", text: $newTripName)
                Button("Create") {
                    let trimmed = newTripName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    let trip = Trip(name: trimmed)
                    modelContext.insert(trip)
                    car.trips.append(trip)
                    newTripName = ""
                }
                Button("Cancel", role: .cancel) { newTripName = "" }
            }
            .sheet(item: $fuelEntryToEdit) { item in
                AddFuelView(car: car, entryToEdit: item.entry)
            }
            .sheet(isPresented: $showCostLog) {
                AddCostView(car: car)
            }
            .sheet(item: $costEntryToEdit) { item in
                AddCostView(car: car, editingTarget: item)
            }
        }
    }

    @ViewBuilder
    private var fuelSection: some View {
        if sortedFuel.isEmpty {
            emptyState(icon: "fuelpump", message: "No fill-ups logged yet")
        } else {
            List {
                let entries = Array(sortedFuel.enumerated())
                ForEach(entries, id: \.element.persistentModelID) { idx, entry in
                    FuelEntryRow(entry: entry, prev: idx < sortedFuel.count - 1 ? sortedFuel[idx + 1] : nil)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            fuelEntryToEdit = EditableFuelEntry(entry: entry)
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
            .padding(.horizontal)
            .scrollDisabled(true)
            .frame(height: CGFloat(sortedFuel.count) * 58 + 2)
            .padding(.bottom, 100)
        }
    }

    @ViewBuilder
    private var costsSection: some View {
        if sortedRecurring.isEmpty && sortedCosts.isEmpty {
            emptyState(icon: "banknote", message: "No costs logged yet")
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !sortedRecurring.isEmpty {
                        sectionHeader("Recurring")
                            .padding(.horizontal)

                        List {
                            ForEach(sortedRecurring, id: \.persistentModelID) { cost in
                                RecurringCostRow(cost: cost)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        costEntryToEdit = .recurring(cost)
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
                        .padding(.horizontal)
                        .frame(height: CGFloat(sortedRecurring.count) * 58 + 2)
                    }

                    if !sortedCosts.isEmpty {
                        sectionHeader("One-Time")
                            .padding(.horizontal)

                        List {
                            ForEach(sortedCosts, id: \.persistentModelID) { cost in
                                OtherCostRow(cost: cost)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        costEntryToEdit = .oneTime(cost)
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
                        .padding(.horizontal)
                        .frame(height: CGFloat(sortedCosts.count) * 58 + 2)
                    }
                }
            }
            .padding(.bottom, 100)
        }
    }

    @ViewBuilder
    private var tripsSection: some View {
        if sortedTrips.isEmpty {
            emptyState(icon: "map", message: "No trips yet — tap + to create one")
        } else {
            List {
                ForEach(sortedTrips, id: \.persistentModelID) { trip in
                    NavigationLink(destination: TripDetailView(trip: trip)) {
                        TripRow(trip: trip)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            modelContext.delete(trip)
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
            .padding(.horizontal)
            .scrollDisabled(true)
            .frame(height: CGFloat(sortedTrips.count) * 58 + 2)
            .padding(.bottom, 100)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(Color.ccTextSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textCase(nil)
    }

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(Color.ccTextMuted)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.ccTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .ccCardSurface(cornerRadius: 18)
        .padding(.horizontal)
        .padding(.top, 4)
        .padding(.bottom, 100)
    }
}

private struct EditableFuelEntry: Identifiable {
    let entry: FuelEntry
    var id: PersistentIdentifier { entry.persistentModelID }
}

struct LogCostFAB: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("Log Cost")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Color.ccTextPrimary)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(Color.ccTeal)
                    .shadow(color: Color.ccTeal.opacity(0.45), radius: 16, x: 0, y: 6)
            )
        }
    }
}

// MARK: - Fuel Entry Row

struct FuelEntryRow: View {
    let entry: FuelEntry
    let prev: FuelEntry?

    private var kmDriven: Double? {
        guard let prev else { return nil }
        return max(0, entry.odometerReading - prev.odometerReading)
    }

    private var efficiency: Double? {
        guard let km = kmDriven, km > 0 else { return nil }
        return (entry.liters / km) * 100
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "fuelpump.fill")
                .font(.callout)
                .foregroundStyle(Color.ccAmber.opacity(0.85))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(formatLiters(entry.liters))
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    Text("@ \(formatEUR(entry.pricePerLiter))/L")
                        .font(.caption)
                        .foregroundStyle(Color.ccTextSecondary)
                    if let trip = entry.trip {
                        TripBadge(name: trip.name)
                    }
                }
                HStack(spacing: 8) {
                    Text("\(Int(entry.odometerReading).formatted()) km")
                        .font(.caption2)
                        .foregroundStyle(Color.ccTextMuted)
                    if let km = kmDriven {
                        Text("+\(Int(km)) km")
                            .font(.caption2)
                            .foregroundStyle(Color.ccTextMuted)
                    }
                    if let eff = efficiency {
                        Text(formatEfficiency(eff))
                            .font(.caption2)
                            .foregroundStyle(Color.ccTeal.opacity(0.8))
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(formatEUR(entry.totalCost))
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(Color.ccTextMuted)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

// MARK: - Recurring Cost Row

struct RecurringCostRow: View {
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
                    .foregroundStyle(.white)
                Text(cost.category.rawValue)
                    .font(.caption2)
                    .foregroundStyle(Color.ccTextMuted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(formatEUR(cost.monthlyAmount))/mo")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text("from \(cost.startDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundStyle(Color.ccTextMuted)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

// MARK: - Other Cost Row

struct OtherCostRow: View {
    let cost: OtherCost

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: cost.category.systemImage)
                .font(.callout)
                .foregroundStyle(Color.ccAmber.opacity(0.85))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(cost.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    if let trip = cost.trip {
                        TripBadge(name: trip.name)
                    }
                }
                HStack(spacing: 6) {
                    Text(cost.category.rawValue)
                        .font(.caption2)
                        .foregroundStyle(Color.ccTextMuted)
                    if !cost.notes.isEmpty {
                        Text("· \(cost.notes)")
                            .font(.caption2)
                            .foregroundStyle(Color.ccTextSecondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(formatEUR(cost.amount))
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(cost.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(Color.ccTextMuted)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

#Preview {
    LogsView(car: Car(name: "", purchasePrice: 1, purchaseDate: Date()))
}
