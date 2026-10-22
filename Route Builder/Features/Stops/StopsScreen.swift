import SwiftUI
import RouteBuilderKit

struct StopsScreen: View {
    @Bindable var model: DispatcherModel
    @State private var quantityStop: Stop?
    @State private var showManual = false
    @State private var scrollTarget: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            modeSwitch
            searchField
            ZStack(alignment: .trailing) {
                stopList
                AlphabetIndex(sections: model.sections) { letter in
                    scrollTarget = letter
                }
            }
            if !model.selected.isEmpty {
                chipsBar
            }
            continueButton
        }
        .background(Theme.canvasStops.ignoresSafeArea())
        .sheet(isPresented: $showManual) {
            ManualStopSheet { name, address, phone in
                model.addManualStop(name: name, address: address, phone: phone)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Morning route — Central area")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(model.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var modeSwitch: some View {
        HStack(spacing: 0) {
            modeButton(
                title: "One stop",
                subtitle: "Single delivery",
                selected: model.mode == .oneStop,
                badge: false
            ) {
                model.setMode(.oneStop)
            }
            modeButton(
                title: "Multi-stop route",
                subtitle: "Several stops",
                selected: model.mode == .multiStop,
                badge: true
            ) {
                model.setMode(.multiStop)
            }
        }
        .padding(4)
        .background(.white, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    private func modeButton(
        title: String,
        subtitle: String,
        selected: Bool,
        badge: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular))
            }
            .foregroundStyle(selected ? Color.white : (title.hasPrefix("Multi") && !selected ? Theme.ink : Theme.muted))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(selected ? Theme.teal : Color.clear, in: RoundedRectangle(cornerRadius: 9))
            .overlay(alignment: .topLeading) {
                if badge {
                    Text("New")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 6)
                        .background(Theme.badge, in: Capsule())
                        .offset(x: -2, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        HStack {
            TextField("Search by name, street, or phone", text: Binding(
                get: { model.searchText },
                set: { model.updateSearch($0) }
            ))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            if !model.searchText.isEmpty {
                Button {
                    model.updateSearch("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(.white, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private var stopList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    if model.isLoadingDirectory && model.directory.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if let error = model.directoryError, model.directory.isEmpty {
                        VStack(spacing: 10) {
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.muted)
                                .multilineTextAlignment(.center)
                            Button("Retry") {
                                Task { await model.loadDirectory() }
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.teal)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                    } else if model.isSearchingActive, (model.searchResults?.isEmpty ?? false), !model.isSearching {
                        emptySearch
                    } else {
                        ForEach(model.sections) { section in
                            Section {
                                ForEach(section.stops) { stop in
                                    stopRow(stop)
                                }
                            } header: {
                                Text(section.letter)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Theme.muted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Theme.canvasStops)
                                    .id(section.letter)
                            }
                        }
                    }
                }
            }
            .onChange(of: scrollTarget) { _, letter in
                guard let letter else { return }
                withAnimation { proxy.scrollTo(letter, anchor: .top) }
                scrollTarget = nil
            }
        }
    }

    private var emptySearch: some View {
        VStack(spacing: 10) {
            Text("No stop found")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("Try another street or enter an address manually")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            Button("Enter address manually") {
                showManual = true
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Theme.teal)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
    }

    private func stopRow(_ stop: Stop) -> some View {
        let selected = model.isSelected(stop)
        return Button {
            model.toggle(stop)
        } label: {
            HStack(spacing: 12) {
                checkbox(selected: selected)
                Text(model.initials.make(from: stop.name))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40)
                    .background(Theme.avatarColor(for: stop.id), in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 2) {
                    Text(stop.name)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(stop.address)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if selected {
                    Button {
                        quantityStop = stop
                    } label: {
                        Text("\(model.packages(for: stop))×")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.teal)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Color.white, in: Capsule())
                            .overlay(Capsule().stroke(Theme.teal, lineWidth: 1))
                            .fixedSize()
                    }
                    .buttonStyle(.plain)
                    // Anchored to the pill itself (not the row/checkbox), arrow
                    // pointing up at it, card opening below the row.
                    .popover(
                        isPresented: quantityBinding(for: stop),
                        attachmentAnchor: .rect(.bounds),
                        arrowEdge: .top
                    ) {
                        QuantityPopover(
                            current: model.packages(for: stop),
                            maxPackages: stop.packagesMax,
                            packageCount: model.packageCount,
                            onSave: { value in
                                model.setPackages(stopID: stop.id, value: value)
                                quantityStop = nil
                            },
                            onDismiss: { quantityStop = nil }
                        )
                    }
                } else {
                    Text(stop.phone)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 10)
            .padding(.leading, 30)
            .padding(.trailing, 14)
            // Mockup "Picker selected": whole row filled #E3F0F1 when checked.
            .background(selected ? Theme.chipFill : Color.white)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.line).frame(height: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func quantityBinding(for stop: Stop) -> Binding<Bool> {
        Binding(
            get: { quantityStop?.id == stop.id },
            set: { presented in
                if !presented, quantityStop?.id == stop.id { quantityStop = nil }
            }
        )
    }

    private func checkbox(selected: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .stroke(selected ? Color.clear : Color(hex: 0xC3CDD4), lineWidth: 1.5)
                .background(selected ? Theme.teal : Color.white, in: RoundedRectangle(cornerRadius: 6))
            if selected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 23, height: 23)
    }

    private var chipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.selected) { item in
                    HStack(spacing: 8) {
                        Text(item.stop.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                            .frame(maxWidth: 108, alignment: .leading)
                        Text("\(item.packages)×")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.teal)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Theme.chipFill, in: Capsule())
                        Button {
                            model.removeSelected(stopID: item.id)
                        } label: {
                            Text("✕")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Color.white)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.line).frame(height: 1)
        }
    }

    private var continueButton: some View {
        Button {
            model.goToInstructions()
        } label: {
            let n = model.selected.count
            let label = n == 1 ? "Continue (1 stop)" : "Continue (\(n) stops)"
            Text(label)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(model.canContinue ? Color.white : Theme.disabledText)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    model.canContinue ? Theme.teal : Theme.disabledFill,
                    in: RoundedRectangle(cornerRadius: 12)
                )
        }
        .disabled(!model.canContinue)
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .background(Color.white)
    }
}
