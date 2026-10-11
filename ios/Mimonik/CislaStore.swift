import Foundation

struct Cislo: Codable, Identifiable, Equatable {
    let id: String
    let nazev: String
    let pdf: String
    let poradi: Int
}

enum SpojeniChyba: Error { case nedostupne }

/// Načítá seznam čísel z webu a stahuje PDF do zařízení (aby šla číst i bez signálu).
@MainActor
final class CislaStore: ObservableObject {
    @Published var cisla: [Cislo] = []
    @Published var nacita = false
    @Published var chyba: String?
    @Published var stazena: Set<String> = []

    init() {
        cisla = Self.ulozenySeznam()
        stazena = Set(cisla.filter { Self.souborPDF($0).exists }.map { $0.id })
    }

    func obnov() async {
        nacita = true
        defer { nacita = false }
        do {
            cisla = try await Self.nactiSeznam()
            chyba = nil
            stazena = Set(cisla.filter { Self.souborPDF($0).exists }.map { $0.id })
        } catch {
            chyba = cisla.isEmpty ? "Seznam čísel se nepodařilo načíst. Zkontroluj připojení." : "Jsi offline, zobrazuji uložená čísla."
        }
    }

    /// Vrátí lokální soubor s PDF; když tam není, stáhne ho.
    func pdf(_ cislo: Cislo) async throws -> URL {
        let cil = Self.souborPDF(cislo)
        if cil.exists { return cil }
        for adresa in Config.adresy {
            guard let url = URL(string: adresa + cislo.pdf) else { continue }
            do {
                let (tmp, odpoved) = try await URLSession.shared.download(from: url)
                guard (odpoved as? HTTPURLResponse)?.statusCode == 200 else { continue }
                try FileManager.default.createDirectory(at: cil.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? FileManager.default.removeItem(at: cil)
                try FileManager.default.moveItem(at: tmp, to: cil)
                stazena.insert(cislo.id)
                return cil
            } catch { continue }
        }
        throw SpojeniChyba.nedostupne
    }

    func smazStazene() {
        for c in cisla { try? FileManager.default.removeItem(at: Self.souborPDF(c)) }
        stazena = []
    }

    // MARK: - sdílené (používá i úloha na pozadí)

    nonisolated static func nactiSeznam() async throws -> [Cislo] {
        for adresa in Config.adresy {
            guard let url = URL(string: adresa + "cisla.json") else { continue }
            var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
            req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            do {
                let (data, odpoved) = try await URLSession.shared.data(for: req)
                guard (odpoved as? HTTPURLResponse)?.statusCode == 200 else { continue }
                let seznam = try JSONDecoder().decode([Cislo].self, from: data)
                    .sorted { $0.poradi > $1.poradi }
                try? data.write(to: seznamSoubor)
                return seznam
            } catch { continue }
        }
        throw SpojeniChyba.nedostupne
    }

    nonisolated static func ulozenySeznam() -> [Cislo] {
        guard let data = try? Data(contentsOf: seznamSoubor),
              let s = try? JSONDecoder().decode([Cislo].self, from: data) else { return [] }
        return s.sorted { $0.poradi > $1.poradi }
    }

    nonisolated static var slozka: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    nonisolated static var seznamSoubor: URL {
        try? FileManager.default.createDirectory(at: slozka, withIntermediateDirectories: true)
        return slozka.appendingPathComponent("cisla.json")
    }

    nonisolated static func souborPDF(_ c: Cislo) -> URL {
        slozka.appendingPathComponent("pdf/\(c.id).pdf")
    }
}

extension URL {
    var exists: Bool { FileManager.default.fileExists(atPath: path) }
}
