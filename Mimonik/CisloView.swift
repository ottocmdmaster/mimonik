import SwiftUI

/// Čtečka jednoho čísla: stáhne PDF (pokud ještě není v zařízení) a zobrazí ho.
struct CisloView: View {
    @EnvironmentObject var store: CislaStore
    let cislo: Cislo
    /// Z hledání napříč čísly: otevřít na této straně a zvýraznit hledané slovo.
    var pocatecniStrana: Int? = nil
    var hledanyText: String? = nil
    @State private var soubor: URL?
    @State private var selhalo = false
    @State private var hledani = ""
    @State private var rezim = RezimCteni.ulozeny
    @State private var oblibene = false
    @State private var zalozky: [Int] = []
    @State private var zobrazeni = false
    @State private var aktivniSheet: ActiveSheet?
    @State private var puvodniJas: CGFloat?
    @State private var jasZeSystemu = false
    @State private var jas = Double(UIScreen.main.brightness)
    @State private var svitit = Stav.nechatSvitit
    @State private var varianta = MimonVarianta.nahodna()
    @State private var zamava = false
    @State private var zaznam = ZaznamCteni()

    private enum ActiveSheet: Identifiable {
        case seznam
        case nahledy
        case nota(NotaCil)
        var id: String {
            switch self {
            case .seznam: return "seznam"
            case .nahledy: return "nahledy"
            case .nota(let n): return n.id.uuidString
            }
        }
    }
    @StateObject private var ovladac = PDFOvladac()

    var body: some View {
        Group {
            if let soubor = soubor {
                PDFViewerView(url: soubor, cisloID: cislo.id, rezim: rezim, ovladac: ovladac, pocatecniStrana: pocatecniStrana)
                    .ignoresSafeArea(edges: .bottom)
                    .overlay(alignment: .bottom) {
                        VStack(spacing: 8) {
                            if let h = ovladac.hlaska {
                                Text(h)
                                    .font(.footnote)
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(.regularMaterial)
                                    .cornerRadius(10)
                            }
                            if zobrazeni {
                                ZobrazeniPanel(rezim: $rezim, jas: $jas, svitit: $svitit, ovladac: ovladac, jasSystem: jasPodleSystemu)
                            }
                        }
                        .padding(.bottom, 8)
                    }
            } else if selhalo {
                VStack(spacing: 12) {
                    Text("Číslo se nepodařilo stáhnout.")
                    Button("Zkusit znovu") { Task { await nacti() } }
                }
            } else {
                VStack(spacing: 12) {
                    MimonChodi(varianta: varianta, zamava: zamava)
                    Text(zamava ? "Hotovo!" : "Stahuji číslo…")
                }
            }
        }
        .navigationTitle(cislo.nazev)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $hledani, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Hledat v čísle")
        .onSubmit(of: .search) { ovladac.hledej(hledani) }
        .onChange(of: hledani) { text in
            if text.isEmpty { ovladac.zrus() }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if ovladac.nalezeno > 0 {
                    Text("\(ovladac.aktualni + 1)/\(ovladac.nalezeno)")
                        .font(.caption).foregroundColor(.secondary)
                    Button { ovladac.predchozi() } label: { Image(systemName: "chevron.up") }
                    Button { ovladac.dalsi() } label: { Image(systemName: "chevron.down") }
                }
                Button { aktivniSheet = .nahledy } label: { Image(systemName: "square.grid.2x2") }
                Button { zobrazeni.toggle() } label: { Image(systemName: "textformat.size") }
                Menu {
                    Button { ovladac.zvyrazni(.yellow) } label: { Label("Zvýraznit žlutě", systemImage: "highlighter") }
                    Button { ovladac.zvyrazni(.green) } label: { Label("Zvýraznit zeleně", systemImage: "highlighter") }
                    Button { ovladac.zvyrazni(.systemPink) } label: { Label("Zvýraznit růžově", systemImage: "highlighter") }
                    Button { ovladac.zacniPoznamku() } label: { Label("Přidat poznámku", systemImage: "note.text.badge.plus") }
                } label: { Image(systemName: "pencil.tip.crop.circle") }
                Menu {
                    Button {
                        Stav.prepniZalozku(cislo.id, ovladac.strana)
                        zalozky = Stav.zalozky(cislo.id)
                    } label: {
                        let je = zalozky.contains(ovladac.strana)
                        Label(je ? "Odebrat záložku (strana \(ovladac.strana + 1))" : "Záložka na straně \(ovladac.strana + 1)",
                              systemImage: je ? "bookmark.slash" : "bookmark")
                    }
                    Button { aktivniSheet = .seznam } label: { Label("Záložky a poznámky", systemImage: "list.bullet") }
                    Button {
                        Stav.prepniOblibene(cislo.id)
                        oblibene = Stav.jePoblibene(cislo.id)
                    } label: {
                        Label(oblibene ? "Odebrat z oblíbených" : "Přidat do oblíbených",
                              systemImage: oblibene ? "star.fill" : "star")
                    }
                    Button {
                        Stav.oznacNeprectene(cislo.id)
                        Notifier.aktualizujOdznak(store.cisla)
                    } label: { Label("Označit jako nepřečtené", systemImage: "circle.fill") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .onChange(of: rezim) { novy in
            UserDefaults.standard.set(novy.rawValue, forKey: RezimCteni.klic)
        }
        .onChange(of: jas) { novy in
            UIScreen.main.brightness = CGFloat(novy)
            if jasZeSystemu { jasZeSystemu = false } else { UserDefaults.standard.set(novy, forKey: Stav.klicJas) }
        }
        .sheet(item: $aktivniSheet) { sheet in
            switch sheet {
            case .seznam:
                ZalozkyView(ovladac: ovladac, cisloID: cislo.id) { aktivniSheet = nil }
            case .nahledy:
                NahledyView(dokument: ovladac.dokument, aktualni: ovladac.strana,
                            vybrat: { ovladac.jdiNaStranu($0) }, zavrit: { aktivniSheet = nil })
            case .nota(let cil):
                NotaEditor(cil: cil, uloz: { text in
                    ovladac.ulozPoznamku(cil, text: text)
                    aktivniSheet = nil
                }, zrus: { aktivniSheet = nil })
            }
        }
        .onAppear {
            oblibene = Stav.jePoblibene(cislo.id)
            zalozky = Stav.zalozky(cislo.id)
            Stav.oznacPrectene(cislo.id)
            Stav.posledniOtevrene = cislo.id
            Stav.zaznamenejOtevreni(cislo.id)
            zaznam.start()
            UIApplication.shared.isIdleTimerDisabled = svitit
            ovladac.naNota = { aktivniSheet = .nota($0) }
            if puvodniJas == nil {
                puvodniJas = UIScreen.main.brightness
                let ulozeny = UserDefaults.standard.object(forKey: Stav.klicJas) as? Double
                if let u = ulozeny { jas = u; UIScreen.main.brightness = CGFloat(u) }
            }
        }
        .onChange(of: svitit) { novy in
            Stav.nechatSvitit = novy
            UIApplication.shared.isIdleTimerDisabled = novy
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            Stav.pridejDobu(cislo.id, sekundy: zaznam.pauza())
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            zaznam.start()
        }
        .onDisappear {
            Stav.pridejDobu(cislo.id, sekundy: zaznam.pauza())
            UIApplication.shared.isIdleTimerDisabled = false
            if let p = puvodniJas { UIScreen.main.brightness = p; puvodniJas = nil }
        }
        .task { await nacti() }
    }

    private func jasPodleSystemu() {
        UserDefaults.standard.removeObject(forKey: Stav.klicJas)
        if let p = puvodniJas {
            UIScreen.main.brightness = p
            jasZeSystemu = true
            jas = Double(p)
        }
    }

    private func nacti() async {
        selhalo = false
        let uzBylo = store.stazena.contains(cislo.id)
        do {
            let url = try await store.pdf(cislo)
            if !uzBylo {
                // skutečné stahování skončilo: mimoň zamává, než se otevře PDF
                zamava = true
                try? await Task.sleep(nanoseconds: 800_000_000)
            }
            soubor = url
            if let text = hledanyText, !text.isEmpty {
                try? await Task.sleep(nanoseconds: 300_000_000)
                hledani = text
                ovladac.hledej(text, naStrane: pocatecniStrana)
            }
        } catch { selhalo = true }
    }
}

/// Měří dobu, po kterou je čtečka otevřená a aplikace aktivní.
struct ZaznamCteni {
    private var od: Date?
    mutating func start() { od = Date() }
    /// Vrátí dobu od posledního `start` a zastaví měření.
    mutating func pauza() -> Double {
        defer { od = nil }
        guard let od = od else { return 0 }
        return Date().timeIntervalSince(od)
    }
}
