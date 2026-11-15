import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var favorites: FavoritesStore

    var body: some View {
        let devices = ATGuideStore.sortDevices(favorites.keys.compactMap { key in
            FavoriteKey.parse(key).flatMap { $0.kind == .device ? store.device($0.id) : nil }
        })
        let companies = favorites.keys.compactMap { key in
            FavoriteKey.parse(key).flatMap { $0.kind == .company ? store.company($0.id) : nil }
        }.sorted { ATGuideStore.nameOrder($0.name, $1.name) }
        let oses = favorites.keys.compactMap { key in
            FavoriteKey.parse(key).flatMap { $0.kind == .os ? store.os($0.id) : nil }
        }.sorted { ATGuideStore.nameOrder($0.name, $1.name) }
        NavigationStack {
            List {
                if devices.isEmpty && companies.isEmpty && oses.isEmpty {
                    Text("No favorites yet. Open any device, company or operating system and choose the Favorite button. Favorites are saved on this device only.")
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !devices.isEmpty {
                    Section {
                        ForEach(devices) { d in
                            DeviceRow(device: d)
                                .swipeActions { removeButton(FavoriteKey.device(d.id), d.name) }
                        }
                    } header: {
                        SectionHeader("Devices and software (\(devices.count))")
                    }
                }
                if !companies.isEmpty {
                    Section {
                        ForEach(companies) { c in
                            CompanyRow(company: c)
                                .swipeActions { removeButton(FavoriteKey.company(c.id), c.name) }
                        }
                    } header: {
                        SectionHeader("Companies (\(companies.count))")
                    }
                }
                if !oses.isEmpty {
                    Section {
                        ForEach(oses) { o in
                            OSRow(os: o)
                                .swipeActions { removeButton(FavoriteKey.os(o.id), o.name) }
                        }
                    } header: {
                        SectionHeader("Operating systems (\(oses.count))")
                    }
                }
                Section {
                    NavigationLink(value: Route.recents) {
                        Text("Recently Viewed")
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .navigationTitle("Favorites")
            .atguideDestinations()
        }
    }

    private func removeButton(_ key: String, _ name: String) -> some View {
        Button(role: .destructive) {
            favorites.remove(key)
        } label: {
            Label("Remove from Favorites", systemImage: "star.slash")
        }
        .accessibilityLabel("Remove \(name) from Favorites")
    }
}
