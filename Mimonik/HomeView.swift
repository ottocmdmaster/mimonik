import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: CislaStore
    @State private var hledani = ""
    @State private var filtr = FiltrSeznamu.vse
    @State private var sdilet: Cislo?
    @AppStorage(Stav.klicVelikostSeznamu) private var velikost = VelikostSeznamu.normalni.rawValue
    @State private var zmena = 0  // změna přečtených/oblíbených čísel → překreslení seznamu

    var body: some View {
        NavigationView {
            List {
                if let rozecteno = rozectene {
                    Section {
                        NavigationLink(destination: CisloView(cislo: rozecteno)) {
                            HStack(spacing: 14) {
                                Image(systemName: "book.fill").font(.title).foregroundColor(.accentColor)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Pokračovat ve čtení").font(.headline)
                                    Text(popisPozice(rozecteno)).foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 10)
                        }
                    }
                }

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

                if let chyba = store.chyba {
                    Section { Text(chyba).font(.footnote).foregroundColor(.secondary) }
                }

                if zobrazena.isEmpty && !store.cisla.isEmpty {
                    Section { Text(prazdnyText).foregroundColor(.secondary) }
                }

                ForEach(skupiny, id: \.rok) { skupina in
                Section(header: Text(String(skupina.rok))) {
                    ForEach(skupina.cisla) { cislo in
                        NavigationLink(destination: CisloView(cislo: cislo)) {
                            HStack {
                                if !Stav.jePrectene(cislo.id) {
                                    Circle().fill(Color.accentColor).frame(width: 9, height: 9)
                                }
                                Text(cislo.nazev)
                                    .font(styl.pismo)
                                    .fontWeight(Stav.jePrectene(cislo.id) ? .regular : .semibold)
                                Spacer()
                                if Stav.jePoblibene(cislo.id) {
                                    Image(systemName: "star.fill").foregroundColor(.yellow)
                                }
                                if store.stazena.contains(cislo.id) {
                                    Image(systemName: "arrow.down.circle.fill").foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, styl.odsazeni)
                        }
                        .swipeActions(edge: .leading) {
                            if Stav.jePrectene(cislo.id) {
                                Button { prepniPrectene(cislo) } label: {
                                    Label("Nepřečtené", systemImage: "circle.fill")
                                }
                                .tint(.accentColor)
                            }
                        }
                        .contextMenu {
                            Button { sdilet = cislo } label: {
                                Label("Sdílet odkaz", systemImage: "square.and.arrow.up")
                            }
                            if Stav.jePrectene(cislo.id) {
                                Button { prepniPrectene(cislo) } label: {
                                    Label("Označit jako nepřečtené", systemImage: "circle.fill")
                                }
                            }
                        }
                    }
                }
                }

                Section {
                    NavigationLink(destination: StatistikyView()) {
                        Label("Statistiky čtení", systemImage: "chart.bar")
                    }
                    NavigationLink(destination: NastaveniView()) {
                        Label("Nastavení", systemImage: "gearshape")
                    }
                }
            }
            .navigationTitle("Mimoník")
            .refreshable { await store.obnov() }
            .searchable(text: $hledani, prompt: "Hledat číslo")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: HledaniView()) { Image(systemName: "magnifyingglass") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Zobrazit", selection: $filtr) {
                            ForEach(FiltrSeznamu.allCases) { f in Text(f.nazev).tag(f) }
                        }
                    } label: {
                        Image(systemName: filtr == .vse ? "line.3.horizontal.decrease.circle"
                                                        : "line.3.horizontal.decrease.circle.fill")
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Stav.zmena)) { _ in zmena += 1 }
            .overlay {
                if store.cisla.isEmpty && store.nacita { ProgressView() }
            }

            // Na iPadu je to druhý sloupec (seznam | čtečka); na iPhonu se nezobrazí.
            VStack(spacing: 12) {
                Image(systemName: "book.closed").font(.system(size: 56)).foregroundColor(.secondary)
                Text("Vyber číslo").font(.title2).foregroundColor(.secondary)
            }
        }
        .modifier(StylNavigace())
        .sheet(item: $sdilet) { SdileniSheet(cislo: $0) }
        .task {
            await store.obnov()
            if Notifier.zapnuto { Notifier.oznacJakoVidene(store.cisla) }
        }
    }

    private func prepniPrectene(_ cislo: Cislo) {
        Stav.oznacNeprectene(cislo.id)
        Notifier.aktualizujOdznak(store.cisla)
    }

    private var styl: VelikostSeznamu { VelikostSeznamu(rawValue: velikost) ?? .normalni }

    /// Poslední otevřené číslo, pokud v něm čtenář někam došel.
    private var rozectene: Cislo? {
        _ = zmena
        guard let id = Stav.posledniOtevrene else { return nil }
        return store.cisla.first { $0.id == id }
    }

    private func popisPozice(_ c: Cislo) -> String {
        guard let s = Stav.pozice(c.id) else { return c.nazev }
        return "\(c.nazev), strana \(s + 1)"
    }

    private var zobrazena: [Cislo] {
        _ = zmena
        return store.cisla.filter { c in
            odpovida(c, filtr) &&
            (hledani.isEmpty || c.nazev.range(of: hledani, options: [.caseInsensitive, .diacriticInsensitive]) != nil)
        }
    }

    private func odpovida(_ c: Cislo, _ f: FiltrSeznamu) -> Bool {
        switch f {
        case .vse: return true
        case .neprectena: return !Stav.jePrectene(c.id)
        case .oblibena: return Stav.jePoblibene(c.id)
        }
    }

    /// Čísla seskupená podle roku vydání, nejnovější rok nahoře.
    private var skupiny: [(rok: Int, cisla: [Cislo])] {
        Dictionary(grouping: zobrazena, by: { $0.rok })
            .map { (rok: $0.key, cisla: $0.value.sorted { $0.poradi > $1.poradi }) }
            .sorted { $0.rok > $1.rok }
    }

    private var prazdnyText: String {
        if !hledani.isEmpty { return "Nic nenalezeno." }
        switch filtr {
        case .vse: return "Žádná čísla."
        case .neprectena: return "Všechna čísla máš přečtená."
        case .oblibena: return "Zatím nemáš žádná oblíbená čísla."
        }
    }
}

/// iPhone = jeden sloupec na celou obrazovku, iPad = seznam čísel vlevo a čtečka vpravo.
private struct StylNavigace: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            content.navigationViewStyle(.automatic)
        } else {
            content.navigationViewStyle(.stack)
        }
    }
}
