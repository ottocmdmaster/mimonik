import XCTest
@testable import Mimonik

final class StavTests: XCTestCase {
    private var puvodni: UserDefaults!
    private let sada = "tl.knyt.MimonikTests.stav"

    override func setUp() {
        super.setUp()
        puvodni = Stav.d
        UserDefaults().removePersistentDomain(forName: sada)
        Stav.d = UserDefaults(suiteName: sada)!
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: sada)
        Stav.d = puvodni
        super.tearDown()
    }

    private func cisla(_ n: Int) -> [Cislo] {
        (1...n).map { Cislo(id: "c\($0)", nazev: "Číslo \($0)", pdf: "c\($0).pdf", poradi: $0) }
    }

    func testPrectenaCislaSePocitajiJakoNeprectena() {
        let c = cisla(3)
        XCTAssertEqual(Stav.pocetNeprectenych(c), 3)
        Stav.oznacPrectene("c2")
        Stav.oznacPrectene("c2")
        XCTAssertTrue(Stav.jePrectene("c2"))
        XCTAssertFalse(Stav.jePrectene("c1"))
        XCTAssertEqual(Stav.pocetNeprectenych(c), 2)
    }

    func testPoziceSeUkladaPoCislech() {
        XCTAssertNil(Stav.pozice("c1"))
        Stav.ulozPozici("c1", 4)
        Stav.ulozPozici("c2", 9)
        Stav.ulozPozici("c1", 6)
        XCTAssertEqual(Stav.pozice("c1"), 6)
        XCTAssertEqual(Stav.pozice("c2"), 9)
    }

    func testOblibenePrepinani() {
        XCTAssertFalse(Stav.jePoblibene("c1"))
        Stav.prepniOblibene("c1")
        XCTAssertTrue(Stav.jePoblibene("c1"))
        Stav.prepniOblibene("c1")
        XCTAssertFalse(Stav.jePoblibene("c1"))
    }

    func testZalozkyJsouSerazeneAPrepinaji() {
        XCTAssertEqual(Stav.zalozky("c1"), [])
        XCTAssertTrue(Stav.prepniZalozku("c1", 5))
        XCTAssertTrue(Stav.prepniZalozku("c1", 2))
        XCTAssertEqual(Stav.zalozky("c1"), [2, 5])
        XCTAssertTrue(Stav.jeZalozka("c1", 5))
        XCTAssertFalse(Stav.prepniZalozku("c1", 5))
        XCTAssertEqual(Stav.zalozky("c1"), [2])
        XCTAssertEqual(Stav.zalozky("c2"), [])
    }

    func testPosledniOtevreneANechatSvitit() {
        XCTAssertNil(Stav.posledniOtevrene)
        Stav.posledniOtevrene = "c3"
        XCTAssertEqual(Stav.posledniOtevrene, "c3")
        XCTAssertTrue(Stav.nechatSvitit, "výchozí je zapnuto")
        Stav.nechatSvitit = false
        XCTAssertFalse(Stav.nechatSvitit)
    }

    func testStatistiky() {
        let c = cisla(3)
        Stav.oznacPrectene("c1")
        Stav.oznacPrectene("c2")
        Stav.ulozPozici("c1", 0)
        Stav.ulozPozici("c1", 1)
        Stav.ulozPozici("c1", 1)
        Stav.ulozPozici("c2", 0)
        Stav.pridejDobu("c1", sekundy: 120)
        Stav.pridejDobu("c2", sekundy: 30)
        Stav.pridejDobu("c2", sekundy: -5)
        let s = Stav.statistiky(c)
        XCTAssertEqual(s.prectenych, 2)
        XCTAssertEqual(s.celkem, 3)
        XCTAssertEqual(s.otevrenychStran, 3)
        XCTAssertEqual(s.sekundCteni, 150, accuracy: 0.001)
        XCTAssertEqual(s.nejctenejsi, "Číslo 1")
    }

    func testFormatDoby() {
        XCTAssertEqual(Stav.formatujDobu(20), "méně než minuta")
        XCTAssertEqual(Stav.formatujDobu(12 * 60), "12 min")
        XCTAssertEqual(Stav.formatujDobu(65 * 60), "1 h 5 min")
    }
}
