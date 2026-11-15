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
                Section(header: Text("Přečtená čísla"),
                        footer: Text("Lišta ukazuje, kolik ze všech čísel jsi už přečetl. Číslo se počítá jako přečtené, když ho otevřeš a zavřeš.")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(s.prectenych) z \(s.celkem) čísel (\(Int((Double(s.prectenych) / Double(s.celkem) * 100).rounded())) %)")
                            .font(.subheadline)
                        ProgressView(value: Double(s.prectenych), total: Double(s.celkem))
                    }
                    .padding(.vertical, 4)
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
