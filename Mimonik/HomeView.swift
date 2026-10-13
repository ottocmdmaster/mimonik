import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: CislaStore
    @State private var hledani = ""
    @State private var jenOblibene = false
    @State private var zmena = 0  // změna přečtených/oblíbených čísel → překreslení seznamu

    var body: some View {
        NavigationView {
            List {
                if let nejnovejsi = store.cisla.first {
                    Section {
                        NavigationLink(destination: CisloView(cislo: nejnovejsi)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Číst nejnovější číslo")
                                    .font(.headline)
                                Text(nejnovejsi.nazev)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }

                Section(header: Text(jenOblibene ? "Oblíbená čísla" : "Všechna čísla"), footer: chybaText) {
                    ForEach(zobrazena) { cislo in
                        NavigationLink(destination: CisloView(cislo: cislo)) {
                            HStack {
                                if !Stav.jePrectene(cislo.id) {
                                    Circle().fill(Color.accentColor).frame(width: 9, height: 9)
                                }
                                Text(cislo.nazev)
                                    .fontWeight(Stav.jePrectene(cislo.id) ? .regular : .semibold)
                                Spacer()
                                if Stav.jePoblibene(cislo.id) {
                                    Image(systemName: "star.fill").foregroundColor(.yellow)
                                }
                                if store.stazena.contains(cislo.id) {
                                    Image(systemName: "arrow.down.circle.fill").foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                Section {
                    NavigationLink(destination: NastaveniView()) {
                        Label("Nastavení upozornění", systemImage: "bell")
                    }
                }
            }
            .navigationTitle("Mimoník")
            .refreshable { await store.obnov() }
            .searchable(text: $hledani, prompt: "Hledat číslo")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { jenOblibene.toggle() } label: {
                        Image(systemName: jenOblibene ? "star.fill" : "star")
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Stav.zmena)) { _ in zmena += 1 }
            .overlay {
                if store.cisla.isEmpty && store.nacita { ProgressView() }
            }
        }
        .navigationViewStyle(.stack)
        .task {
            await store.obnov()
            if Notifier.zapnuto { Notifier.oznacJakoVidene(store.cisla) }
        }
    }

    private var zobrazena: [Cislo] {
        _ = zmena
        return store.cisla.filter { c in
            (!jenOblibene || Stav.jePoblibene(c.id)) &&
            (hledani.isEmpty || c.nazev.range(of: hledani, options: [.caseInsensitive, .diacriticInsensitive]) != nil)
        }
    }

    private var chybaText: some View {
        Group { if let chyba = store.chyba { Text(chyba) } }
    }
}
