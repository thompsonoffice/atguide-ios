import SwiftUI
import UIKit

/// Side-by-side comparison of two or three devices. Instead of a wide grid, each fact is a
/// heading followed by one line per device, so VoiceOver reads "Battery, heading",
/// then "BrailleNote mPower, 20 hours", then the next device, in a fixed order.
struct CompareView: View {
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var compare: CompareStore
    @AppStorage("atguide.compare.differencesOnly") private var differencesOnly = false
    @State private var showingPicker = false

    var body: some View {
        let picked = compare.ids.compactMap { store.device($0) }
        let rows = store.comparisonRows(for: picked)
        let shown = differencesOnly ? rows.filter(\.differs) : rows
        NavigationStack {
            List {
                Section {
                    if picked.isEmpty {
                        Text("Pick two or three devices to compare their specs side by side. Use Add Device below, or the Add to Compare button on any device page.")
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(Array(picked.enumerated()), id: \.element.id) { index, device in
                        HStack(alignment: .firstTextBaseline) {
                            NavigationLink(value: Route.device(device.id)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Device \(index + 1): \(device.name)").font(.body.weight(.semibold))
                                    Text("\(store.companyName(device.company)), \(device.releasedText)")
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) { compare.remove(device.id) } label: {
                                Label("Remove", systemImage: "minus.circle")
                            }
                        }
                        .accessibilityAction(named: "Remove from Compare") { compare.remove(device.id) }
                    }
                    if !picked.isEmpty {
                        Button("Clear Comparison", role: .destructive) { compare.removeAll() }
                            .font(.body)
                            .foregroundStyle(Color.destructiveText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } header: {
                    SectionHeader("Devices (\(picked.count) of \(CompareStore.capacity))")
                }

                if picked.count >= 2 {
                    if differencesOnly && shown.isEmpty {
                        Text("Every fact matches.")
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    ForEach(shown) { row in
                        Section {
                            ForEach(Array(zip(picked, row.values).enumerated()), id: \.offset) { _, pair in
                                LabeledFact(label: pair.0.name, value: pair.1)
                            }
                        } header: {
                            SectionHeader(row.label)
                        }
                    }
                } else if picked.count == 1 {
                    Text("Add one or two more devices to see the comparison.")
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .navigationTitle("Compare")
            .font(.body)
            .aboveTabBar()
            .safeAreaInset(edge: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    if picked.count >= 2 {
                        Button {
                            differencesOnly.toggle()
                        } label: {
                            Text(differencesOnly ? "Showing only differences" : "Show only differences")
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(differencesOnly ? .isSelected : [])
                        .accessibilityHint("Hides facts that are the same for every picked device.")
                        Text("\(shown.count) of \(rows.count) facts shown.")
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    if !compare.isFull {
                        Button("Add Device") { showingPicker = true }
                            .font(.body)
                            .foregroundColor(.primary)
                            .buttonStyle(.plain)
                            .accessibilityHint("\(compare.ids.count) of \(CompareStore.capacity) devices picked.")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(uiColor: .systemBackground))
            }
            .atguideDestinations()
            .sheet(isPresented: $showingPicker) {
                ComparePickerView()
            }
        }
    }
}

/// A searchable list for adding a device to the comparison.
struct ComparePickerView: View {
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
                        }
                        .foregroundStyle(.primary)
                    }
                } header: {
                    Text("\(results.count) devices")
                        .textCase(nil)
                        .foregroundStyle(.primary)
                        .accessibilityAddTraits(.isHeader)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Find a device to add")
            .autocorrectionDisabled()
            .navigationTitle("Add Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
