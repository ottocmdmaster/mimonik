import XCTest
@testable import Mimonik

/// Podvrhne odpovědi webu, aby se stahování testovalo bez sítě.
final class WebStub: URLProtocol {
    nonisolated(unsafe) static var odpoved: (URL) -> (Int, Data) = { _ in (404, Data()) }
    nonisolated(unsafe) static var pozadavky: [URL] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let url = request.url!
        Self.pozadavky.append(url)
        let (kod, data) = Self.odpoved(url)
        let r = HTTPURLResponse(url: url, statusCode: kod, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: r, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class CislaStoreTests: XCTestCase {
    private var cislo: Cislo!

    private var stubKonfigurace: URLSessionConfiguration {
        let k = URLSessionConfiguration.ephemeral
        k.protocolClasses = [WebStub.self]
        return k
    }

    override func setUp() {
        super.setUp()
        cislo = Cislo(id: "test-\(UUID().uuidString)", nazev: "Test", pdf: "test.pdf", poradi: 1)
        WebStub.pozadavky = []
        WebStub.odpoved = { _ in (404, Data()) }
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: CislaStore.souborPDF(cislo))
        super.tearDown()
    }

    func testSeznamSeDekodujeAJeSerazenyOdNejnovejsiho() throws {
        let json = """
        [{"id":"a","nazev":"A","pdf":"a.pdf","poradi":1},
         {"id":"c","nazev":"C","pdf":"c.pdf","poradi":3},
         {"id":"b","nazev":"B","pdf":"b.pdf","poradi":2}]
        """
        let soubor = CislaStore.seznamSoubor
        let zaloha = try? Data(contentsOf: soubor)
        defer { if let z = zaloha { try? z.write(to: soubor) } else { try? FileManager.default.removeItem(at: soubor) } }
        try json.data(using: .utf8)!.write(to: soubor)
        XCTAssertEqual(CislaStore.ulozenySeznam().map(\.id), ["c", "b", "a"])
    }

    func testPoskozenySeznamDaPrazdnePole() throws {
        let soubor = CislaStore.seznamSoubor
        let zaloha = try? Data(contentsOf: soubor)
        defer { if let z = zaloha { try? z.write(to: soubor) } else { try? FileManager.default.removeItem(at: soubor) } }
        try "{není json".data(using: .utf8)!.write(to: soubor)
        XCTAssertEqual(CislaStore.ulozenySeznam(), [])
    }

    func testStazeniUlozíPDFAPodruheNestahuje() async throws {
        let obsah = Data("%PDF-1.4 test".utf8)
        WebStub.odpoved = { _ in (200, obsah) }
        let url = try await CislaStore.stahniPDF(cislo, konfigurace: stubKonfigurace)
        XCTAssertEqual(url, CislaStore.souborPDF(cislo))
        XCTAssertEqual(try Data(contentsOf: url), obsah)
        let pocet = WebStub.pozadavky.count
        XCTAssertGreaterThan(pocet, 0)
        _ = try await CislaStore.stahniPDF(cislo, konfigurace: stubKonfigurace)
        XCTAssertEqual(WebStub.pozadavky.count, pocet, "už stažené PDF se nestahuje znovu")
    }

    func testStazenePDFSeNikdyNepřepíše() async throws {
        let cil = CislaStore.souborPDF(cislo)
        try FileManager.default.createDirectory(at: cil.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("moje poznámky".utf8).write(to: cil)
        WebStub.odpoved = { _ in (200, Data("nové".utf8)) }
        _ = try await CislaStore.stahniPDF(cislo, konfigurace: stubKonfigurace)
        XCTAssertEqual(try String(contentsOf: cil), "moje poznámky")
        XCTAssertTrue(WebStub.pozadavky.isEmpty)
    }

    func testChybaWebuHodiNedostupne() async {
        WebStub.odpoved = { _ in (500, Data()) }
        do {
            _ = try await CislaStore.stahniPDF(cislo, konfigurace: stubKonfigurace)
            XCTFail("měla přijít chyba")
        } catch {
            XCTAssertTrue(error is SpojeniChyba)
        }
        XCTAssertFalse(CislaStore.souborPDF(cislo).exists)
    }

    func testZalozniAdresaSePouzijeKdyzPrvniNeodpovi() async throws {
        let prvni = Config.adresy[0]
        WebStub.odpoved = { url in url.absoluteString.hasPrefix(prvni) ? (503, Data()) : (200, Data("ok".utf8)) }
        let url = try await CislaStore.stahniPDF(cislo, konfigurace: stubKonfigurace)
        XCTAssertTrue(url.exists)
        XCTAssertEqual(WebStub.pozadavky.count, 2)
    }
}
