import SwiftUI
import RouteBuilderKit

struct AlphabetIndex: View {
    let sections: [StopSection]
    let onSelect: (String) -> Void

    private let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map(String.init)

    private var available: Set<String> {
        Set(sections.map(\.letter))
    }

    var body: some View {
        VStack(spacing: 1) {
            if available.contains("#") {
                letterButton("#")
            }
            ForEach(letters, id: \.self) { letter in
                letterButton(letter)
            }
        }
        .padding(.vertical, 4)
        .padding(.trailing, 2)
    }

    @ViewBuilder
    private func letterButton(_ letter: String) -> some View {
        let active = available.contains(letter)
        Button {
            if active { onSelect(letter) }
        } label: {
            Text(letter)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(active ? Theme.teal : Theme.indexDim)
                .frame(width: 14, height: 11)
        }
        .disabled(!active)
        .buttonStyle(.plain)
    }
}
