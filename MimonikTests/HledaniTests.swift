import XCTest
import PDFKit
@testable import Mimonik

final class HledaniTests: XCTestCase {
    private func index(_ strany: [String]) -> IndexCisla { IndexCisla(velikost: 1, zmeneno: 1, strany: strany) }

    func testNormalizaceOdstraniDiakritikuAVelikost() {
        XCTAssertEqual(HledaniStore.normalizuj("Žluťoučký KŮŇ"), "zlutoucky kun")
    }

    func testHledaniBezDiakritikyAVelikostiPisma() {
        let i = ["c1": index(["Úvod do tramvají", "Dnes vyjel žlutý autobus"]), "c2": index(["Nic zajímavého"])]
        let n = HledaniStore.hledej("ZLUTY", v: i)
        XCTAssertEqual(n.count, 1)
        XCTAssertEqual(n.first?.cisloID, "c1")
        XCTAssertEqual(n.first?.strana, 1)
        XCTAssertTrue(n.first?.ukazka.contains("žlutý") ?? false)
    }

    func testVsechnaSlovaMusiBytNaStrane() {
        let i = ["c1": index(["tramvaj a autobus", "jen tramvaj"])]
        XCTAssertEqual(HledaniStore.hledej("tramvaj autobus", v: i).map(\.strana), [0])
        XCTAssertEqual(HledaniStore.hledej("tramvaj", v: i).count, 2)
    }

    func testPrazdnyDotazNicNevraci() {
        XCTAssertTrue(HledaniStore.hledej("   ", v: ["c1": index(["text"])]).isEmpty)
    }

    func testUkazkaMaOkoliAUtrhavaKonce() {
        let dlouhy = String(repeating: "a ", count: 60) + "hledane" + String(repeating: " b", count: 60)
        let u = HledaniStore.ukazka(text: dlouhy, slovo: "hledane")
        XCTAssertTrue(u.contains("hledane"))
        XCTAssertTrue(u.hasPrefix("…"))
        XCTAssertTrue(u.hasSuffix("…"))
        XCTAssertLessThan(u.count, 130)
    }

    func testIndexaceSkutecnehoPDF() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("hledani-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        let r = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 400, height: 400))
        try r.writePDF(to: url) { ctx in
            for text in ["První stránka mimoň", "Druhá stránka tramvaj"] {
                ctx.beginPage()
                (text as NSString).draw(at: CGPoint(x: 20, y: 20), withAttributes: [.font: UIFont.systemFont(ofSize: 18)])
            }
        }
        let i = try XCTUnwrap(HledaniStore.zaindexuj(url))
        XCTAssertEqual(i.strany.count, 2)
        let n = HledaniStore.hledej("tramvaj", v: ["x": i])
        XCTAssertEqual(n.map(\.strana), [1])
        XCTAssertEqual(HledaniStore.hledej("MIMON", v: ["x": i]).map(\.strana), [0])
    }

    func testPripravaIndexuPoznaZmenenyAChybejiciSoubor() throws {
        let c1 = Cislo(id: "idx-\(UUID().uuidString)", nazev: "1", pdf: "1.pdf", poradi: 1)
        let c2 = Cislo(id: "idx-\(UUID().uuidString)", nazev: "2", pdf: "2.pdf", poradi: 2)
        let soubor = CislaStore.souborPDF(c1)
        try FileManager.default.createDirectory(at: soubor.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("abc".utf8).write(to: soubor)
        defer { try? FileManager.default.removeItem(at: soubor) }
        let info = try XCTUnwrap(HledaniStore.informace(soubor))

        // sedí velikost i čas → index se použije; c2 není stažené → vynechá se
        var p = HledaniStore.priprav(index: [c1.id: IndexCisla(velikost: info.velikost, zmeneno: info.zmeneno, strany: ["a"])], cisla: [c1, c2])
        XCTAssertEqual(Set(p.index.keys), [c1.id])
        XCTAssertTrue(p.chybi.isEmpty)

        // jiná velikost → je třeba přeindexovat
        p = HledaniStore.priprav(index: [c1.id: IndexCisla(velikost: 999, zmeneno: info.zmeneno, strany: ["a"])], cisla: [c1])
        XCTAssertTrue(p.index.isEmpty)
        XCTAssertEqual(p.chybi.map(\.id), [c1.id])

        // číslo bez indexu → chybí
        p = HledaniStore.priprav(index: [:], cisla: [c1])
        XCTAssertEqual(p.chybi.map(\.id), [c1.id])
    }
}
