import SwiftUI

/// Čtečka jednoho čísla: stáhne PDF (pokud ještě není v zařízení) a zobrazí ho.
struct CisloView: View {
    @EnvironmentObject var store: CislaStore
    let cislo: Cislo
    @State private var soubor: URL?
    @State private var selhalo = false
    @State private var hledani = ""
    @State private var rezim = RezimCteni.ulozeny
    @State private var oblibene = false
    @StateObject private var ovladac = PDFOvladac()

    var body: some View {
        Group {
            if let soubor = soubor {
                PDFViewerView(url: soubor, cisloID: cislo.id, rezim: rezim, ovladac: ovladac)
                    .ignoresSafeArea(edges: .bottom)
            } else if selhalo {
                VStack(spacing: 12) {
                    Text("Číslo se nepodařilo stáhnout.")
                    Button("Zkusit znovu") { Task { await nacti() } }
                }
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Stahuji číslo…")
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
                Menu {
                    Picker("Režim čtení", selection: $rezim) {
                        ForEach(RezimCteni.allCases) { Text($0.nazev).tag($0) }
                    }
                } label: { Image(systemName: "circle.lefthalf.filled") }
                Button {
                    Stav.prepniOblibene(cislo.id)
                    oblibene = Stav.jePoblibene(cislo.id)
                } label: { Image(systemName: oblibene ? "star.fill" : "star") }
            }
        }
        .onChange(of: rezim) { novy in
            UserDefaults.standard.set(novy.rawValue, forKey: RezimCteni.klic)
        }
        .onAppear {
            oblibene = Stav.jePoblibene(cislo.id)
            Stav.oznacPrectene(cislo.id)
        }
        .task { await nacti() }
    }

    private func nacti() async {
        selhalo = false
        do { soubor = try await store.pdf(cislo) } catch { selhalo = true }
    }
}
