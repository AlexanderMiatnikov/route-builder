import SwiftUI
import RouteBuilderKit

struct PhotoStrip: View {
    let photos: [DeliveryPhoto]?
    let isLocal: Bool

    private struct Slot: Identifiable {
        let tag: String
        let title: String
        var id: String { tag }
    }

    /// Always three slots, in mockup order. Photos are matched by tag so a missing
    /// or null-url photo leaves its own slot as a placeholder instead of shifting others.
    private static let slots = [
        Slot(tag: "entrance", title: "Entrance"),
        Slot(tag: "parking", title: "Parking"),
        Slot(tag: "back_door", title: "Back door")
    ]

    var body: some View {
        if isLocal {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Photos from the last delivery")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
                HStack(spacing: 6) {
                    ForEach(Self.slots) { slot in
                        cell(for: slot)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cell(for slot: Slot) -> some View {
        Group {
            if let photos {
                if let photo = photos.first(where: { $0.tag == slot.tag }) {
                    AsyncImage(url: photo.url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure:
                            placeholder
                        default:
                            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                } else {
                    placeholder
                }
            } else {
                // Still loading from GET /v1/stops/{id}/photos.
                placeholder.overlay { ProgressView() }
            }
        }
        .frame(height: 60)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .bottom) {
            Text(slot.title)
                .font(.system(size: 10))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)
                .background(Color(hex: 0x16232E).opacity(0.62))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    colors: [Color(hex: 0xDCE4E8), Color(hex: 0xE9EEF1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}
