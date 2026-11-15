import SwiftUI

/// Správa stažených čísel: velikost, smazání jednoho nebo všech (znovu se stáhnou při otevření).
struct StazenaView: View {
    @EnvironmentObject var store: CislaStore
    @State private var velikosti: [String: Int64] = [:]
    @State private var potvrdit = false

    private var stazena: [Cislo] { store.cisla.filter { store.stazena.contains($0.id) } }
    private var celkem: Int64 { stazena.reduce(0) { $0 + (velikosti[$1.id] ?? 0) } }

    var body: some View {
        List {
            if stazena.isEmpty {
                Text("Žádné stažené číslo.").foregroundColor(.secondary)
            } else {
                Section(footer: Text("Smazané číslo se znovu stáhne, až ho otevřeš. Poznámky a zvýraznění v něm se smažou spolu s ním.")) {
                    ForEach(stazena) { c in
                        HStack {
                            Text(c.nazev)
                            Spacer()
                            Text(Self.format(velikosti[c.id] ?? 0)).foregroundColor(.secondary)
                        }
                        .swipeActions {
                            Button(role: .destructive) { store.smaz(c) } label: { Label("Smazat", systemImage: "trash") }
                        }
                    }
                }
                Section {
                    Button("Smazat všechna stažená čísla (\(Self.format(celkem)))", role: .destructive) { potvrdit = true }
                }
            }
        }
        .navigationTitle("Stažená čísla")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.obnovStazena(); spocitej() }
        .onReceive(store.$stazena) { _ in spocitej() }
        .alert("Smazat všechna stažená čísla?", isPresented: $potvrdit) {
            Button("Smazat", role: .destructive) { store.smazStazene() }
            Button("Zrušit", role: .cancel) {}
        } message: {
            Text("Poznámky a zvýraznění uložené v nich se smažou.")
        }
    }

    private func spocitej() {
        velikosti = Dictionary(uniqueKeysWithValues: stazena.map { ($0.id, CislaStore.velikost($0)) })
    }

    private static func format(_ bajty: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bajty, countStyle: .file)
    }
}
