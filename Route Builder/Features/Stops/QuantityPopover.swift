import SwiftUI
import RouteBuilderKit

struct QuantityPopover: View {
    let maxPackages: Int?
    @State private var value: Int
    let onSave: (Int) -> Void
    let onDismiss: () -> Void

    init(current: Int, maxPackages: Int?, onSave: @escaping (Int) -> Void, onDismiss: @escaping () -> Void) {
        self.maxPackages = maxPackages
        self._value = State(initialValue: PackageCount.clamp(current, max: maxPackages))
        self.onSave = onSave
        self.onDismiss = onDismiss
    }

    private var upper: Int {
        if let maxPackages, maxPackages >= 1 { return maxPackages }
        return PackageCount.fallbackMax
    }

    var body: some View {
        VStack(spacing: 14) {
            Text("Number of packages")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)

            HStack(spacing: 18) {
                Button {
                    value = PackageCount.clamp(value - 1, max: maxPackages)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(Theme.canvasStops, in: RoundedRectangle(cornerRadius: 10))
                }
                .disabled(value <= 1)

                Text("\(value)")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                    .frame(minWidth: 48)

                Button {
                    value = PackageCount.clamp(value + 1, max: maxPackages)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(Theme.canvasStops, in: RoundedRectangle(cornerRadius: 10))
                }
                .disabled(value >= upper)
            }
            .foregroundStyle(Theme.ink)

            Button {
                onSave(value)
            } label: {
                Text("Save")
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .foregroundStyle(.white)
                    .background(Theme.teal, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(18)
        .frame(width: 260)
        // Presented with `.popover` anchored to the quantity pill; the system
        // draws the card, arrow and shadow, so no custom chrome here.
        .presentationCompactAdaptation(.popover)
    }
}
