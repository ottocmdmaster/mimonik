import SwiftUI

/// Nastavení upozornění na nová čísla.
struct NastaveniView: View {
    @EnvironmentObject var store: CislaStore
    @State private var oznameni = Notifier.zapnuto
    @State private var zablokovano = false
    @State private var ticho = Notifier.tichoZapnuto
    @State private var tichoOd = Self.datum(Notifier.tichoOd)
    @State private var tichoDo = Self.datum(Notifier.tichoDo)
    @State private var interval = Notifier.interval
    @State private var autoStahovat = Notifier.autoStahovat
    @State private var jenWifi = Notifier.jenWifi
    @State private var kontroluji = false
    @State private var vysledek: String?

    var body: some View {
        Form {
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

            if oznameni {
                Section(header: Text("Jak často"), footer: Text("Je to jen požadavek, iPhone kontrolu spustí, kdy uzná za vhodné.")) {
                    Picker("Kontrolovat", selection: $interval) {
                        ForEach(Notifier.intervaly, id: \.self) { h in
                            Text(h == 1 ? "každou hodinu" : "každé \(h) h").tag(h)
                        }
                    }
                    .onChange(of: interval) { h in
                        Notifier.interval = h
                        Notifier.naplanujKontrolu()
                    }
                }

                Section(header: Text("Tiché hodiny"), footer: Text("V tichých hodinách upozornění nepřijde.")) {
                    Toggle("Nerušit", isOn: $ticho)
                        .onChange(of: ticho) { Notifier.tichoZapnuto = $0 }
                    if ticho {
                        DatePicker("Od", selection: $tichoOd, displayedComponents: .hourAndMinute)
                            .onChange(of: tichoOd) { Notifier.tichoOd = Self.minuty($0) }
                        DatePicker("Do", selection: $tichoDo, displayedComponents: .hourAndMinute)
                            .onChange(of: tichoDo) { Notifier.tichoDo = Self.minuty($0) }
                    }
                }
            }

            Section(header: Text("Stahování"), footer: Text("Nové číslo se stáhne hned, jak ho appka najde (při kontrole na pozadí i po otevření), aby šlo číst bez signálu. Už stažené číslo se nikdy nepřepíše.")) {
                Toggle("Stahovat nové číslo automaticky", isOn: $autoStahovat)
                    .onChange(of: autoStahovat) { Notifier.autoStahovat = $0 }
                if autoStahovat {
                    Toggle("Jen na Wi-Fi", isOn: $jenWifi)
                        .onChange(of: jenWifi) { Notifier.jenWifi = $0 }
                }
            }

            Section(footer: vysledek.map { Text($0) }) {
                Button {
                    Task { await zkontrolujTed() }
                } label: {
                    HStack {
                        Text("Zkontrolovat teď")
                        if kontroluji { Spacer(); ProgressView() }
                    }
                }
                .disabled(kontroluji)
            }
        }
        .navigationTitle("Upozornění")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let povoleno = await Notifier.povoleno()
            zablokovano = Notifier.zapnuto && !povoleno
        }
    }

    private func prepni(_ zapnout: Bool) async {
        let ok = await Notifier.nastav(zapnout)
        oznameni = ok
        zablokovano = zapnout && !ok
    }

    private func zkontrolujTed() async {
        kontroluji = true
        vysledek = nil
        let nove = await Notifier.kontrola(rucne: true)
        await store.obnov()
        store.obnovStazena()
        kontroluji = false
        switch nove {
        case .none: vysledek = "Web se nepodařilo zkontrolovat. Zkus to později."
        case .some(true): vysledek = "Vyšlo nové číslo: \(store.cisla.first?.nazev ?? "")."
        case .some(false): vysledek = "Žádné nové číslo, máš to nejnovější."
        }
    }

    private static func datum(_ minuty: Int) -> Date {
        Calendar.current.date(bySettingHour: minuty / 60, minute: minuty % 60, second: 0, of: Date()) ?? Date()
    }

    private static func minuty(_ d: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}
