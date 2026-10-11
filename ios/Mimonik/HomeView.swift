import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: CislaStore
    @State private var oznameni = Notifier.zapnuto
    @State private var zablokovano = false

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

                Section(header: Text("Všechna čísla"), footer: chybaText) {
                    ForEach(store.cisla) { cislo in
                        NavigationLink(destination: CisloView(cislo: cislo)) {
                            HStack {
                                Text(cislo.nazev)
                                Spacer()
                                if store.stazena.contains(cislo.id) {
                                    Image(systemName: "arrow.down.circle.fill").foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                Section(footer: Text("Appka občas v pozadí zkontroluje, jestli nevyšlo nové číslo. Kdy přesně, určuje iPhone, takže upozornění může přijít s odstupem hodin.")) {
                    Toggle("Upozornit na nové číslo", isOn: Binding(
                        get: { oznameni },
                        set: { zapnout in Task { await prepni(zapnout) } }
                    ))
                    if zablokovano {
                        Button("Povolit oznámení v Nastavení") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Mimoník")
            .refreshable { await store.obnov() }
            .overlay {
                if store.cisla.isEmpty && store.nacita { ProgressView() }
            }
        }
        .navigationViewStyle(.stack)
        .task {
            await store.obnov()
            if Notifier.zapnuto { Notifier.oznacJakoVidene(store.cisla) }
            let povoleno = await Notifier.povoleno()
            zablokovano = Notifier.zapnuto && !povoleno
        }
    }

    private var chybaText: some View {
        Group { if let chyba = store.chyba { Text(chyba) } }
    }

    private func prepni(_ zapnout: Bool) async {
        let vysledek = await Notifier.nastav(zapnout)
        oznameni = vysledek
        zablokovano = zapnout && !vysledek
    }
}
