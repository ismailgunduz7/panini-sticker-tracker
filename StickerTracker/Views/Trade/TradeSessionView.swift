import SwiftUI

/// Interactive trade: the collector picks which matched stickers actually
/// changed hands, then applies them to their album in one step. Nothing is
/// pre-selected — people rarely trade every spare they hold, so each sticker
/// received or given is an explicit tap.
///
/// Applying:
/// - received stickers become owned (`setOwned`),
/// - given stickers lose one duplicate (`adjustDuplicates(by: -1)`).
struct TradeSessionView: View {
    @Environment(CollectionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let theirs: TradePayload
    var title: String = String(localized: "Trade")

    @State private var receiving: Set<String> = []
    @State private var giving: Set<String> = []
    @State private var summary: String?

    private var receiveGroups: [TradeGroup] {
        TradeMatch.theyGiveYou(mine: .current(store), theirs: theirs)
    }
    private var giveGroups: [TradeGroup] {
        TradeMatch.youGiveThem(mine: .current(store), theirs: theirs)
    }

    var body: some View {
        NavigationStack {
            List {
                direction(
                    "They can give you",
                    groups: receiveGroups,
                    selection: $receiving
                )
                direction(
                    "You can give them",
                    groups: giveGroups,
                    selection: $giving
                )
            }
            .navigationTitle(Text(verbatim: title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { applyBar }
            .alert("Trade Applied", isPresented: .constant(summary != nil)) {
                Button("OK") { dismiss() }
            } message: {
                if let summary { Text(verbatim: summary) }
            }
        }
    }

    // MARK: - Direction section

    @ViewBuilder
    private func direction(
        _ header: LocalizedStringKey,
        groups: [TradeGroup],
        selection: Binding<Set<String>>
    ) -> some View {
        let allCodes = groups.flatMap(\.codes)
        Section {
            if groups.isEmpty {
                Text("No matches")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(verbatim: group.title)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Button(selection.wrappedValue.isSuperset(of: group.codes)
                                   ? "Deselect All" : "Select All") {
                                toggleAll(group.codes, selection: selection)
                            }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.borderless)
                        }
                        chips(for: group.codes, selection: selection)
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            HStack {
                Text(header)
                Spacer()
                if !allCodes.isEmpty {
                    Button(selection.wrappedValue.isSuperset(of: allCodes)
                           ? "Deselect All" : "Select All") {
                        toggleAll(allCodes, selection: selection)
                    }
                    .font(.caption.weight(.semibold))
                    .textCase(nil)
                    Text(verbatim: "\(selection.wrappedValue.intersection(allCodes).count)/\(allCodes.count)")
                        .monospacedDigit()
                }
            }
        }
    }

    private func chips(for codes: [String], selection: Binding<Set<String>>) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 64), spacing: 8)],
            spacing: 8
        ) {
            ForEach(codes, id: \.self) { code in
                let isSelected = selection.wrappedValue.contains(code)
                Button {
                    if isSelected { selection.wrappedValue.remove(code) }
                    else { selection.wrappedValue.insert(code) }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                        Text(verbatim: code)
                            .font(.caption.weight(.semibold).monospaced())
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 6)
                    .foregroundStyle(isSelected ? Color.white : Color.secondary)
                    .background(
                        isSelected
                            ? AnyShapeStyle(Color.accentColor)
                            : AnyShapeStyle(Color(.secondarySystemGroupedBackground)),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isSelected ? Color.clear : Color.secondary.opacity(0.3))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: code))
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
    }

    // MARK: - Apply bar

    private var applyBar: some View {
        VStack(spacing: 8) {
            Text("Receiving \(receiving.count) · Giving \(giving.count)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Button {
                apply()
            } label: {
                Text("Apply Trade")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(receiving.isEmpty && giving.isEmpty)
        }
        .padding()
        .background(.bar)
    }

    // MARK: - Actions

    private func toggleAll(_ codes: [String], selection: Binding<Set<String>>) {
        if selection.wrappedValue.isSuperset(of: codes) {
            selection.wrappedValue.subtract(codes)
        } else {
            selection.wrappedValue.formUnion(codes)
        }
    }

    private func apply() {
        let added = receiving.count
        let removed = giving.count
        store.setOwned(Array(receiving), owned: true)
        for code in giving {
            store.adjustDuplicates(code, by: -1)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        summary = String(
            localized: "Added \(added) to your album and removed \(removed) duplicate(s)."
        )
    }
}

#Preview {
    TradeSessionView(theirs: TradePayload(owned: ["MEX1", "MEX2"], duplicates: ["MEX2", "BRA1"]))
        .environment(CollectionStore(repository: PreviewRepository()))
}
