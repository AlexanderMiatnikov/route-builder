import SwiftUI
import RouteBuilderKit

struct PhotoStrip: View {
    let photos: [DeliveryPhoto]?
    let isLocal: Bool

    var body: some View {
        if isLocal {
            EmptyView()
        } else if let photos, photos.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Photos from the last delivery")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
                HStack(spacing: 6) {
                    if let photos {
                        ForEach(photos) { photo in
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
                            .frame(height: 60)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(alignment: .bottom) {
                                Text(photo.tagTitle)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 2)
                                    .background(Color(hex: 0x16232E).opacity(0.62))
                            }
                        }
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                    }
                }
            }
        }
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
