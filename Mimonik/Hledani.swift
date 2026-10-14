import Foundation
import PDFKit

/// Text jednoho čísla po stranách spolu s údaji, podle kterých se pozná, že je PDF jiné.
struct IndexCisla: Codable, Equatable {
    var velikost: Int
    var zmeneno: Double
    var strany: [String]
}

/// Jeden nález hledaného slova.
struct Nalez: Identifiable, Equatable {
    let cisloID: String
    let strana: Int
    let ukazka: String
    var id: String { "\(cisloID)-\(strana)" }
}

/// Fulltextový index všech stažených čísel (uložený na disku), hledání bez diakritiky a velikosti písmen.
@MainActor
final class HledaniStore: ObservableObject {
    @Published var index: [String: IndexCisla] = [:]
    @Published var buduje = false
    @Published var hotovo = 0
    @Published var celkem = 0

    init() { index = Self.nactiIndex() }

    /// Doplní index o stažená čísla (a smaže ty, která už stažená nejsou nebo se změnila).
    func aktualizuj(_ cisla: [Cislo]) async {
        guard !buduje else { return }
        let aktualni = Self.priprav(index: index, cisla: cisla)
        index = aktualni.index
        let chybi = aktualni.chybi
        guard !chybi.isEmpty else { return }
        buduje = true
        hotovo = 0
        celkem = chybi.count
        for c in chybi {
            let soubor = CislaStore.souborPDF(c)
            let novy = await Task.detached(priority: .utility) { Self.zaindexuj(soubor) }.value
            if let novy = novy { index[c.id] = novy }
            hotovo += 1
        }
        Self.uloz(index)
        buduje = false
    }

    func hledej(_ dotaz: String) -> [Nalez] { Self.hledej(dotaz, v: index) }

    // MARK: - čistá logika (testovatelná)

    /// Malá písmena bez diakritiky.
    nonisolated static func normalizuj(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "cs"))
    }

    /// Co v indexu platí a která stažená čísla je třeba (znovu) zaindexovat.
    nonisolated static func priprav(index: [String: IndexCisla], cisla: [Cislo]) -> (index: [String: IndexCisla], chybi: [Cislo]) {
        var vysl: [String: IndexCisla] = [:]
        var chybi: [Cislo] = []
        for c in cisla {
            let soubor = CislaStore.souborPDF(c)
            guard let info = informace(soubor) else { continue }
            if let i = index[c.id], i.velikost == info.velikost, i.zmeneno == info.zmeneno {
                vysl[c.id] = i
            } else {
                chybi.append(c)
            }
        }
        return (vysl, chybi)
    }

    nonisolated static func informace(_ url: URL) -> (velikost: Int, zmeneno: Double)? {
        guard let a = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
        let velikost = (a[.size] as? NSNumber)?.intValue ?? 0
        let zmeneno = (a[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return (velikost, zmeneno)
    }

    nonisolated static func zaindexuj(_ url: URL) -> IndexCisla? {
        guard let info = informace(url), let doc = PDFDocument(url: url) else { return nil }
        let strany = (0..<doc.pageCount).map { doc.page(at: $0)?.string ?? "" }
        return IndexCisla(velikost: info.velikost, zmeneno: info.zmeneno, strany: strany)
    }

    /// Najde dotaz (všechna slova musí být na stránce) a ke každé straně připojí úryvek.
    nonisolated static func hledej(_ dotaz: String, v index: [String: IndexCisla]) -> [Nalez] {
        let slova = normalizuj(dotaz).split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !slova.isEmpty else { return [] }
        var vysl: [Nalez] = []
        for (id, cislo) in index {
            for (i, text) in cislo.strany.enumerated() {
                let n = normalizuj(text)
                guard slova.allSatisfy({ n.contains($0) }) else { continue }
                vysl.append(Nalez(cisloID: id, strana: i, ukazka: ukazka(text: text, slovo: slova[0])))
            }
        }
        return vysl
    }

    /// Okolí prvního výskytu slova (normalizace zachovává délku jen přibližně, proto se hledá po znacích původního textu).
    nonisolated static func ukazka(text: String, slovo: String) -> String {
        let jednoduchy = text.replacingOccurrences(of: "\n", with: " ")
        let znaky = Array(jednoduchy)
        let hledany = Array(slovo)
        var zacatek = 0
        if !hledany.isEmpty, znaky.count >= hledany.count {
            for i in 0...(znaky.count - hledany.count) {
                let kus = String(znaky[i..<(i + hledany.count)])
                if normalizuj(kus) == slovo { zacatek = i; break }
            }
        }
        let od = max(0, zacatek - 40)
        let do_ = min(znaky.count, zacatek + hledany.count + 60)
        var s = String(znaky[od..<do_]).trimmingCharacters(in: .whitespaces)
        if od > 0 { s = "…" + s }
        if do_ < znaky.count { s += "…" }
        return s
    }

    // MARK: - disk

    nonisolated static var indexSoubor: URL {
        CislaStore.slozka.appendingPathComponent("index.json")
    }

    nonisolated static func nactiIndex() -> [String: IndexCisla] {
        guard let data = try? Data(contentsOf: indexSoubor),
              let i = try? JSONDecoder().decode([String: IndexCisla].self, from: data) else { return [:] }
        return i
    }

    nonisolated static func uloz(_ index: [String: IndexCisla]) {
        try? FileManager.default.createDirectory(at: CislaStore.slozka, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(index) { try? data.write(to: indexSoubor) }
    }
}
