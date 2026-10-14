import SwiftUI

/// Hledání slova napříč všemi staženými čísly.
struct HledaniView: View {
    @EnvironmentObject var store: CislaStore
    @StateObject private var hledani = HledaniStore()
    @State private var dotaz = ""
    @State private var stahuji = false
    @State private var stazeno = 0

    var body: some View {
        List {
            if hledani.buduje {
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Indexuji čísla… \(hledani.hotovo)/\(hledani.celkem)")
                    }
                }
            }

            let nestazena = store.cisla.filter { !store.stazena.contains($0.id) }
            if !nestazena.isEmpty {
                Section(footer: Text("Hledá se jen ve stažených číslech. Nestažených zbývá \(nestazena.count).")) {
                    Button {
                        Task { await stahniVse(nestazena) }
                    } label: {
                        HStack {
                            Text("Stáhnout všechna čísla")
                            if stahuji { Spacer(); Text("\(stazeno)/\(nestazena.count + stazeno)").foregroundColor(.secondary) }
                        }
                    }
                    .disabled(stahuji)
                }
            }

            ForEach(skupiny, id: \.cislo.id) { skupina in
                Section(header: Text(skupina.cislo.nazev)) {
                    ForEach(skupina.nalezy) { n in
                        NavigationLink(destination: CisloView(cislo: skupina.cislo, pocatecniStrana: n.strana, hledanyText: dotaz)) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Strana \(n.strana + 1)").font(.caption).foregroundColor(.secondary)
                                Text(n.ukazka).font(.subheadline).lineLimit(3)
                            }
                        }
                    }
                }
            }

            if !dotaz.isEmpty && !hledani.buduje && skupiny.isEmpty {
                Section { Text("Nic nenalezeno.").foregroundColor(.secondary) }
            }
        }
        .navigationTitle("Hledání v číslech")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $dotaz, placement: .navigationBarDrawer(displayMode: .always), prompt: "Hledat ve všech číslech")
        .task { await hledani.aktualizuj(store.cisla) }
    }

    private var skupiny: [(cislo: Cislo, nalezy: [Nalez])] {
        let nalezy = hledani.hledej(dotaz)
        guard !nalezy.isEmpty else { return [] }
        let podleCisla = Dictionary(grouping: nalezy, by: { $0.cisloID })
        return store.cisla.compactMap { c in
            guard let n = podleCisla[c.id] else { return nil }
            return (c, n.sorted { $0.strana < $1.strana })
        }
    }

    private func stahniVse(_ cisla: [Cislo]) async {
        stahuji = true
        stazeno = 0
        for c in cisla {
            _ = try? await store.pdf(c)
            stazeno += 1
        }
        store.obnovStazena()
        stahuji = false
        await hledani.aktualizuj(store.cisla)
    }
}
