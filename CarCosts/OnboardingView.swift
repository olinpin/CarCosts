import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var carName = ""
    @State private var purchasePriceText = ""
    @State private var purchaseDate = Date()

    private var canSave: Bool {
        !carName.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(purchasePriceText.replacingOccurrences(of: ",", with: ".")) != nil
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 36) {
                    Spacer(minLength: 60)

                    // Hero
                    VStack(spacing: 12) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.white)
                            .shadow(color: .white.opacity(0.3), radius: 20)
                        Text("CarCosts")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Know what your car truly costs per kilometre")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                    }

                    // Form
                    VStack(spacing: 16) {
                        GlassInputField(
                            title: "Car name",
                            text: $carName,
                            placeholder: "e.g. VW Golf"
                        )

                        GlassInputField(
                            title: "Purchase price (EUR)",
                            text: $purchasePriceText,
                            placeholder: "e.g. 25000",
                            keyboardType: .decimalPad
                        )

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Purchase date")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))

                            DatePicker("", selection: $purchaseDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                                .colorScheme(.dark)
                                .labelsHidden()
                        }
                    }
                    .padding(.horizontal, 24)

                    // CTA
                    Button(action: saveCar) {
                        Text("Get Started")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 24)
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.4)

                    Spacer(minLength: 40)
                }
            }
        }
    }

    private func saveCar() {
        guard let price = Double(purchasePriceText.replacingOccurrences(of: ",", with: ".")),
              !carName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let car = Car(name: carName.trimmingCharacters(in: .whitespaces), purchasePrice: price, purchaseDate: purchaseDate)
        modelContext.insert(car)
    }
}
