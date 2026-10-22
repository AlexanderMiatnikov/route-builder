import SwiftUI
import RouteBuilderKit

struct InstructionsScreen: View {
    @Bindable var model: DispatcherModel
    @State private var cameraStopID: String?
    @State private var focusedID: String?
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        ZStack {
            Theme.canvasInstructions.ignoresSafeArea()
            decorativeBlobs

            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    GeometryReader { geo in
                        ScrollView {
                            LazyVStack(spacing: 18) {
                                ForEach(Array(model.selected.enumerated()), id: \.element.id) { index, item in
                                    instructionCard(item, index: index, viewport: geo.size.height)
                                        .id(item.id)
                                }
                                Color.clear.frame(height: 100)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        }
                        .onAppear { scrollProxy = proxy }
                    }
                }

                bottomBar
            }

            if let undo = model.undo {
                undoBanner(undo)
            }
        }
        .task(id: model.selected.map(\.id)) {
            for item in model.selected {
                await model.loadPhotosIfNeeded(for: item.stop)
            }
        }
        .sheet(item: Binding(
            get: { cameraStopID.map(CameraTarget.init) },
            set: { cameraStopID = $0?.id }
        )) { target in
            CameraCapture(source: .camera) { data in
                if let data {
                    _ = model.savePhotoJPEG(data, stopID: target.id)
                }
            }
            .ignoresSafeArea()
        }
    }

    private var decorativeBlobs: some View {
        ZStack {
            Circle()
                .fill(Theme.teal.opacity(0.10))
                .frame(width: 300, height: 300)
                .offset(x: 90, y: -150)
            Circle()
                .fill(Theme.teal.opacity(0.10))
                .frame(width: 220, height: 220)
                .offset(x: -70, y: 280)
        }
        .allowsHitTesting(false)
    }

    private func instructionCard(_ item: SelectedStop, index: Int, viewport: CGFloat) -> some View {
        let photos = model.photosByStop[item.stop.id]
        return InstructionCardView(
            item: item,
            photos: photos,
            onInstructions: { model.setInstructions(stopID: item.id, text: $0) },
            onClear: { model.clearInstructions(stopID: item.id) },
            onRemove: { model.removeFromRoute(stopID: item.id) },
            onCamera: { cameraStopID = item.id }
        )
        .background(
            GeometryReader { cardGeo in
                Color.clear.preference(
                    key: CardFocusKey.self,
                    value: [item.id: cardGeo.frame(in: .global).midY]
                )
            }
        )
        .onPreferenceChange(CardFocusKey.self) { mids in
            guard let mid = mids[item.id] else { return }
            let center = viewport / 2 + 80
            if abs(mid - center) < 140 {
                focusedID = item.id
            }
        }
        .scaleEffect(scale(for: item.id))
        .opacity(opacity(for: item.id))
        .blur(radius: blur(for: item.id))
        .animation(.easeOut(duration: 0.2), value: focusedID)
    }

    private func scale(for id: String) -> CGSize {
        let focused = focusedID == id || (focusedID == nil && model.selected.first?.id == id)
        return focused ? CGSize(width: 1, height: 1) : CGSize(width: 0.80, height: 0.94)
    }

    private func opacity(for id: String) -> Double {
        let focused = focusedID == id || (focusedID == nil && model.selected.first?.id == id)
        return focused ? 1 : 0.65
    }

    private func blur(for id: String) -> CGFloat {
        let focused = focusedID == id || (focusedID == nil && model.selected.first?.id == id)
        return focused ? 0 : 3
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            switch model.submitPhase {
            case .idle, .sending:
                Button {
                    if let bad = model.validateInstructions() {
                        withAnimation { scrollProxy?.scrollTo(bad, anchor: .center) }
                        focusedID = bad
                        return
                    }
                    Task { await model.finish() }
                } label: {
                    Group {
                        if case .sending = model.submitPhase {
                            ProgressView().tint(.white)
                        } else {
                            Text("Finish instructions")
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.teal, in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled({
                    if case .sending = model.submitPhase { return true }
                    return false
                }())

            case .failure(let message):
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.amberText)
                    .multilineTextAlignment(.center)
                Button {
                    Task { await model.finish() }
                } label: {
                    Text("Retry send")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Theme.teal, in: RoundedRectangle(cornerRadius: 12))
                }

            case .success(let routeID, let notifies):
                VStack(alignment: .leading, spacing: 6) {
                    Text("Route \(routeID) created")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    ForEach(notifies, id: \.stopID) { note in
                        Text("\(note.stopID): \(note.status)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(note.sent ? Theme.teal : Theme.amberText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    model.startAnotherRoute()
                } label: {
                    Text("Start another route")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Theme.teal, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(.ultraThinMaterial)
    }

    private func undoBanner(_ undo: UndoToken) -> some View {
        VStack {
            Spacer()
            HStack {
                Text("Removed \(undo.item.stop.name)")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                Spacer()
                Button("Undo") { model.undoRemove() }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.badge)
            }
            .padding(14)
            .background(Theme.remove, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 14)
            .padding(.bottom, 100)
        }
    }
}

private struct CameraTarget: Identifiable {
    let id: String
}

private struct CardFocusKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

private struct InstructionCardView: View {
    let item: SelectedStop
    let photos: [DeliveryPhoto]?
    let onInstructions: (String) -> Void
    let onClear: () -> Void
    let onRemove: () -> Void
    let onCamera: () -> Void

    @State private var offsetX: CGFloat = 0

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.remove)
                .overlay(alignment: .leading) {
                    Text("Remove from route")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.leading, 14)
                        .frame(width: 150, alignment: .leading)
                }

            cardBody
                .offset(x: offsetX)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offsetX = min(150, max(0, value.translation.width))
                        }
                        .onEnded { value in
                            if value.translation.width > 110 {
                                withAnimation { offsetX = 150 }
                                onRemove()
                                offsetX = 0
                            } else {
                                withAnimation { offsetX = 0 }
                            }
                        }
                )
        }
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(item.stop.name)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer()
                Text("\(item.packages)×")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.teal)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(.white, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(item.showInstructionError ? Theme.amber : Theme.teal, lineWidth: 1.5)
            )

            Text(item.stop.address)
                .font(.system(size: 11))
                .foregroundStyle(Theme.teal)

            PhotoStrip(photos: photos, isLocal: item.stop.isLocal)

            TextField("Special instructions for the driver…", text: Binding(
                get: { item.instructions },
                set: onInstructions
            ), axis: .vertical)
            .font(.system(size: 15))
            .foregroundStyle(Theme.ink)
            .lineLimit(3...6)
            .padding(10)
            .frame(minHeight: 84, alignment: .topLeading)
            .background(.white, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(item.showInstructionError ? Theme.amber : Theme.line, lineWidth: item.showInstructionError ? 1.5 : 1)
            )

            if item.showInstructionError {
                HStack(spacing: 8) {
                    Text("!")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 15, height: 15)
                        .background(Theme.amber, in: Circle())
                    Text("Add instructions for this stop before finishing")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.amberText)
                }
            }

            HStack {
                Text("\(item.instructions.count)/\(InstructionRules.maxCharacters)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.muted)
                Spacer()
                Button("Clear all", action: onClear)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .underline()
            }

            Button(action: onCamera) {
                HStack(spacing: 10) {
                    Image(systemName: "camera")
                        .foregroundStyle(Theme.muted)
                    Text(item.photoPath == nil ? "Photo of the drop-off point" : "Drop-off photo saved on device")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, 12)
                .frame(height: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                        .foregroundStyle(Theme.line)
                )
                .background(.white, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Text("Instructions save automatically and go to the driver when you finish")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.12), radius: 12, y: 6)
    }
}
