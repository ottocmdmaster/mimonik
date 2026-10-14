import SwiftUI

/// Co a jak dlouho jsi četl.
struct StatistikyView: View {
    @EnvironmentObject var store: CislaStore

    var body: some View {
        let s = Stav.statistiky(store.cisla)
        List {
            Section {
                radek("Přečtená čísla", "\(s.prectenych) z \(s.celkem)", "book.closed")
                radek("Otevřené stránky", "\(s.otevrenychStran)", "doc.plaintext")
                radek("Doba čtení", Stav.formatujDobu(s.sekundCteni), "clock")
                if let n = s.nejctenejsi {
                    radek("Nejčtenější číslo", n, "star")
                }
            }
            if s.celkem > 0 {
                Section(footer: Text("Číslo se počítá jako přečtené, když ho otevřeš.")) {
                    ProgressView(value: Double(s.prectenych), total: Double(s.celkem))
                }
            }
        }
        .navigationTitle("Statistiky")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func radek(_ nadpis: String, _ hodnota: String, _ ikona: String) -> some View {
        HStack {
            Label(nadpis, systemImage: ikona)
            Spacer()
            Text(hodnota).foregroundColor(.secondary).multilineTextAlignment(.trailing)
        }
    }
}
