import SwiftUI

/// Čtečka jednoho čísla: stáhne PDF (pokud ještě není v zařízení) a zobrazí ho.
struct CisloView: View {
    @EnvironmentObject var store: CislaStore
    let cislo: Cislo
    @State private var soubor: URL?
    @State private var selhalo = false

    var body: some View {
        Group {
            if let soubor = soubor {
                PDFViewerView(url: soubor)
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
        .task { await nacti() }
    }

    private func nacti() async {
        selhalo = false
        do { soubor = try await store.pdf(cislo) } catch { selhalo = true }
    }
}
