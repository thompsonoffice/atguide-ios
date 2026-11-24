import SwiftUI

struct MacCompareList: View {
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var compare: CompareStore
    @EnvironmentObject private var nav: MacNavState
    @AppStorage("atguide.compare.differencesOnly") private var differencesOnly = false
    @State private var showingPicker = false

    var body: some View {
        let picked = compare.ids.compactMap { store.device($0) }
        List(selection: deviceSelection) {
            Section {
                if picked.isEmpty {
                    Text("Pick two or three devices to compare their specs side by side. Use Add Device below, or the Add to Compare button on any device page.")
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(Array(picked.enumerated()), id: \.element.id) { index, device in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Device \(index + 1): \(device.name)").font(.body.weight(.semibold))
                        Text("\(store.companyName(device.company)), \(device.releasedText)")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .tag(device.id)
                    .contextMenu {
                        Button("Remove from Compare", role: .destructive) { compare.remove(device.id) }
                    }
                    .accessibilityAction(named: "Remove from Compare") { compare.remove(device.id) }
                }
            } header: {
                MacSectionHeader("Devices (\(picked.count) of \(CompareStore.capacity))")
            }

            Section {
                if picked.count >= 2 {
                    Button {
                        differencesOnly.toggle()
                    } label: {
                        Text(differencesOnly ? "Showing only differences" : "Show only differences")
                            .font(.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(differencesOnly ? .isSelected : [])
                    .accessibilityHint("Hides facts that are the same for every picked device.")
                }
                if !picked.isEmpty {
                    Button("Clear Comparison", role: .destructive) { compare.removeAll() }
                        .foregroundStyle(Color.macDestructiveText)
                        .buttonStyle(.plain)
                }
                if !compare.isFull {
                    Button("Add Device") { showingPicker = true }
                        .buttonStyle(.plain)
                        .accessibilityHint("\(compare.ids.count) of \(CompareStore.capacity) devices picked.")
                }
            }

            if picked.count == 1 {
                Text("Add one or two more devices to see the comparison.")
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .navigationTitle("Compare")
        .sheet(isPresented: $showingPicker) {
            MacComparePickerView()
                .frame(minWidth: 420, minHeight: 480)
        }
    }

    private var deviceSelection: Binding<String?> {
        Binding(
            get: {
                if case .device(let id)? = nav.selection { return id }
                return nil
            },
            set: { if let id = $0 { nav.selection = .device(id) } }
        )
    }
}

/// The comparison itself is shown in the detail column when two or more devices are picked.
struct MacCompareDetail: View {
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var compare: CompareStore
    @AppStorage("atguide.compare.differencesOnly") private var differencesOnly = false

    var body: some View {
        let picked = compare.ids.compactMap { store.device($0) }
        let rows = store.comparisonRows(for: picked)
        let shown = differencesOnly ? rows.filter(\.differs) : rows
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Compare")
                    .font(.largeTitle.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                if picked.count < 2 {
                    MacBodyText("Add two or three devices to see the comparison.")
                } else {
                    Text(differencesOnly
                         ? "\(shown.count) of \(rows.count) facts shown, differences only."
                         : "\(shown.count) facts shown.")
                        .font(.body)
                    if differencesOnly && shown.isEmpty {
                        MacBodyText("Every fact matches.")
                    }
                    ForEach(shown) { row in
                        MacDetailSection(row.label) {
                            ForEach(Array(zip(picked, row.values).enumerated()), id: \.offset) { _, pair in
                                MacLabeledFact(label: pair.0.name, value: pair.1)
                            }
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: 800, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Compare")
    }
}

struct MacComparePickerView: View {
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var compare: CompareStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        let results = store.searchDevices(query).filter { !compare.contains($0.id) }
        NavigationStack {
            List {
                Section {
                    ForEach(results) { device in
                        Button {
                            compare.add(device.id)
                            AccessibilityNotification.Announcement("Added \(device.name) to Compare.").post()
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.name).font(.body.weight(.semibold))
                                Text([device.category, store.companyName(device.company), device.releasedText].joined(separator: ", "))
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .accessibilityElement(children: .combine)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("\(results.count) devices")
                        .textCase(nil)
                        .foregroundStyle(.primary)
                        .accessibilityAddTraits(.isHeader)
                }
            }
            .searchable(text: $query, placement: .toolbar, prompt: "Find a device to add")
            .autocorrectionDisabled()
            .navigationTitle("Add Device")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
