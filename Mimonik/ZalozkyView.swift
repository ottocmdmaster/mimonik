import SwiftUI
import PDFKit

/// Sheet se záložkami na stránky a se zvýrazněními a poznámkami z PDF.
struct ZalozkyView: View {
    @ObservedObject var ovladac: PDFOvladac
    let cisloID: String
    let zavrit: () -> Void
    @State private var zalozky: [Int] = []
    @State private var polozky: [PolozkaAnotace] = []

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Záložky")) {
                    if zalozky.isEmpty {
                        Text("Zatím žádné. Záložku přidáš z menu „…“ v čtečce.").foregroundColor(.secondary)
                    }
                    ForEach(zalozky, id: \.self) { s in
                        Button { ovladac.jdiNaStranu(s); zavrit() } label: { Text("Strana \(s + 1)") }
                    }
                    .onDelete { idx in
                        for i in idx { Stav.prepniZalozku(cisloID, zalozky[i]) }
                        obnov()
                    }
                }
                Section(header: Text("Zvýraznění a poznámky")) {
                    if polozky.isEmpty {
                        Text("Zatím žádné.").foregroundColor(.secondary)
                    }
                    ForEach(polozky) { p in
                        Button { ovladac.jdiNaStranu(p.index); zavrit() } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: p.poznamka ? "note.text" : "highlighter")
                                    .foregroundColor(Color(p.anotace.color))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.text.isEmpty ? "(bez textu)" : p.text).lineLimit(3)
                                    Text("Strana \(p.index + 1)").font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                    .onDelete { idx in
                        for i in idx { ovladac.smaz(polozky[i].anotace, na: polozky[i].strana) }
                        obnov()
                    }
                }
            }
            .navigationTitle("Záložky a poznámky")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { EditButton() }
                ToolbarItem(placement: .navigationBarTrailing) { Button("Hotovo", action: zavrit) }
            }
            .onAppear(perform: obnov)
        }
        .navigationViewStyle(.stack)
    }

    private func obnov() {
        zalozky = Stav.zalozky(cisloID)
        polozky = ovladac.polozky()
    }
}

/// Editor textu poznámky (nové i existující; prázdný text poznámku smaže).
struct NotaEditor: View {
    let cil: NotaCil
    let uloz: (String) -> Void
    let zrus: () -> Void
    @State private var text: String

    init(cil: NotaCil, uloz: @escaping (String) -> Void, zrus: @escaping () -> Void) {
        self.cil = cil
        self.uloz = uloz
        self.zrus = zrus
        _text = State(initialValue: cil.anotace?.contents ?? "")
    }

    var body: some View {
        NavigationView {
            TextEditor(text: $text)
                .padding(8)
                .navigationTitle(cil.anotace == nil ? "Nová poznámka" : "Poznámka")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) { Button("Zrušit", action: zrus) }
                    ToolbarItem(placement: .navigationBarTrailing) { Button("Uložit") { uloz(text) } }
                    ToolbarItem(placement: .bottomBar) {
                        if cil.anotace != nil {
                            Button("Smazat poznámku", role: .destructive) { uloz("") }
                        }
                    }
                }
        }
        .navigationViewStyle(.stack)
    }
}

/// Panel „Zobrazení“: režim čtení, jas a zoom.
struct ZobrazeniPanel: View {
    @Binding var rezim: RezimCteni
    @Binding var jas: Double
    @Binding var svitit: Bool
    let ovladac: PDFOvladac
    let jasSystem: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Picker("Režim čtení", selection: $rezim) {
                ForEach(RezimCteni.allCases) { Text($0.nazev).tag($0) }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                Image(systemName: "sun.min")
                Slider(value: $jas, in: 0.05...1)
                Image(systemName: "sun.max")
                Button("Systém", action: jasSystem).font(.footnote)
            }

            Toggle("Nezhasínat obrazovku", isOn: $svitit)

            HStack(spacing: 12) {
                Button { ovladac.oddalit() } label: { Image(systemName: "minus.magnifyingglass") }
                Button { ovladac.priblizit() } label: { Image(systemName: "plus.magnifyingglass") }
                Spacer()
                Button("Na šířku") { ovladac.naSirku() }
            }
            .font(.title3)
        }
        .padding(16)
        .background(.regularMaterial)
        .cornerRadius(14)
        .shadow(radius: 6)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
}
