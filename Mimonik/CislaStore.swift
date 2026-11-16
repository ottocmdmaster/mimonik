import Foundation
import PDFKit

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
            obnovStazena()
            if let nejnovejsi = cisla.first, !Self.souborPDF(nejnovejsi).exists, Notifier.autoStahovat {
                Task { _ = await Notifier.autoStahni(nejnovejsi); obnovStazena() }
            }
        } catch {
            chyba = cisla.isEmpty ? "Seznam čísel se nepodařilo načíst. Zkontroluj připojení." : "Jsi offline, zobrazuji uložená čísla."
        }
    }

    /// Vrátí lokální soubor s PDF; když tam není, stáhne ho.
    func pdf(_ cislo: Cislo) async throws -> URL {
        let cil = try await Self.stahniPDF(cislo)
        stazena.insert(cislo.id)
        return cil
    }

    /// Obnoví seznam stažených podle souborů na disku.
    func obnovStazena() {
        stazena = Set(cisla.filter { Self.souborPDF($0).exists }.map { $0.id })
    }

    /// Smaže stažené PDF jednoho čísla (znovu se stáhne, až ho otevřeš).
    func smaz(_ cislo: Cislo) {
        try? FileManager.default.removeItem(at: Self.souborPDF(cislo))
        stazena.remove(cislo.id)
    }

    nonisolated static func velikost(_ c: Cislo) -> Int64 {
        let atr = try? FileManager.default.attributesOfItem(atPath: souborPDF(c).path)
        return (atr?[.size] as? NSNumber)?.int64Value ?? 0
    }

    func smazStazene() {
        for c in cisla { try? FileManager.default.removeItem(at: Self.souborPDF(c)) }
        stazena = []
    }

    // MARK: - sdílené (používá i úloha na pozadí)

    /// Vrátí lokální PDF; když tam není, stáhne ho. Už stažený soubor nikdy nepřepíše.
    /// `jenWifi` zakáže mobilní data (i datově zpoplatněné sítě, např. hotspot).
    nonisolated static func stahniPDF(_ cislo: Cislo, jenWifi: Bool = false,
                                      konfigurace: URLSessionConfiguration = .default) async throws -> URL {
        let cil = souborPDF(cislo)
        if cil.exists { return cil }
        konfigurace.timeoutIntervalForRequest = 30
        if jenWifi {
            konfigurace.allowsCellularAccess = false
            konfigurace.allowsExpensiveNetworkAccess = false
        }
        let sezeni = URLSession(configuration: konfigurace)
        defer { sezeni.finishTasksAndInvalidate() }
        for adresa in Config.adresy {
            guard let url = URL(string: adresa + cislo.pdf) else { continue }
            do {
                let (tmp, odpoved) = try await sezeni.download(from: url)
                guard (odpoved as? HTTPURLResponse)?.statusCode == 200 else { continue }
                try FileManager.default.createDirectory(at: cil.deletingLastPathComponent(), withIntermediateDirectories: true)
                if cil.exists { try? FileManager.default.removeItem(at: tmp) }
                else {
                    try FileManager.default.moveItem(at: tmp, to: cil)
                    ulozEtag(cislo.id, (odpoved as? HTTPURLResponse)?.value(forHTTPHeaderField: "Etag"))
                }
                return cil
            } catch is CancellationError { throw CancellationError() }
            catch { if Task.isCancelled { throw CancellationError() }; continue }
        }
        throw SpojeniChyba.nedostupne
    }

    // MARK: - změněné PDF na webu

    private nonisolated static let klicEtag = "etagPDF"

    nonisolated static func ulozenyEtag(_ id: String) -> String? {
        (UserDefaults.standard.dictionary(forKey: klicEtag) as? [String: String])?[id]
    }

    nonisolated static func ulozEtag(_ id: String, _ etag: String?) {
        var m = (UserDefaults.standard.dictionary(forKey: klicEtag) as? [String: String]) ?? [:]
        m[id] = etag
        UserDefaults.standard.set(m, forKey: klicEtag)
    }

    /// Má PDF zvýraznění nebo poznámky čtenáře?
    nonisolated static func maAnotace(_ url: URL) -> Bool {
        guard let doc = PDFDocument(url: url) else { return false }
        for i in 0..<doc.pageCount {
            for a in doc.page(at: i)?.annotations ?? [] {
                let typ = (a.type ?? "").replacingOccurrences(of: "/", with: "")
                if typ == "Highlight" || typ == "Text" { return true }
            }
        }
        return false
    }

    /// Když se PDF na webu změnilo od stažení (jiný ETag), smaže místní kopii, aby se stáhla znovu.
    /// Staré kopie bez zaznamenaného ETagu se smažou jen tehdy, když v nich nejsou poznámky čtenáře.
    nonisolated static func obnovZmenene(_ cislo: Cislo) async {
        let cil = souborPDF(cislo)
        guard cil.exists else { return }
        for adresa in Config.adresy {
            guard let url = URL(string: adresa + cislo.pdf) else { continue }
            var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
            req.httpMethod = "HEAD"
            guard let (_, odp) = try? await URLSession.shared.data(for: req),
                  let h = odp as? HTTPURLResponse, h.statusCode == 200,
                  let etag = h.value(forHTTPHeaderField: "Etag") else { continue }
            let ulozeny = ulozenyEtag(cislo.id)
            if ulozeny == etag { return }
            if ulozeny == nil && maAnotace(cil) { ulozEtag(cislo.id, etag); return }
            try? FileManager.default.removeItem(at: cil)
            ulozEtag(cislo.id, nil)
            return
        }
    }

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
