import SwiftUI

struct ContentView: View {
    @State private var model = DispatcherModel()

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Group {
                switch model.tab {
                case .stops:
                    StopsScreen(model: model)
                case .instructions:
                    InstructionsScreen(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(model.tab == .stops ? Theme.canvasStops : Theme.canvasInstructions)
        .task {
            await model.bootstrap()
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: "Stops", tab: .stops, enabled: true)
            tabButton(
                title: "Instructions",
                tab: .instructions,
                enabled: model.canContinue || model.tab == .instructions
            )
        }
        .background(Color.white)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.line).frame(height: 1)
        }
    }

    private func tabButton(title: String, tab: AppTab, enabled: Bool) -> some View {
        Button {
            guard enabled else { return }
            model.tab = tab
        } label: {
            VStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 14, weight: model.tab == tab ? .bold : .regular))
                    .foregroundStyle(model.tab == tab ? Theme.teal : Theme.muted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                Rectangle()
                    .fill(model.tab == tab ? Theme.teal : Color.clear)
                    .frame(height: 3)
            }
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.45)
        .disabled(!enabled)
    }
}

#Preview {
    ContentView()
}
