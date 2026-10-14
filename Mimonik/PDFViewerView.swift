import SwiftUI
import PDFKit

enum RezimCteni: String, CaseIterable, Identifiable {
    case normalni, sepie, tmavy
    var id: String { rawValue }
    var nazev: String {
        switch self {
        case .normalni: return "Normální"
        case .sepie: return "Sépie"
        case .tmavy: return "Tmavý"
        }
    }
    static let klic = "rezimCteni"
    static var ulozeny: RezimCteni {
        RezimCteni(rawValue: UserDefaults.standard.string(forKey: klic) ?? "") ?? .normalni
    }
}

/// Cíl poznámky: nové místo na stránce, nebo existující poznámka k úpravě.
struct NotaCil: Identifiable {
    let id = UUID()
    let strana: PDFPage
    let bod: CGPoint
    let anotace: PDFAnnotation?
}

/// Drží PDFView a výsledky hledání, aby je mohl ovládat toolbar.
final class PDFOvladac: ObservableObject {
    fileprivate weak var pdfView: PDFView?
    fileprivate var soubor: URL?
    @Published var strana = 0
    @Published var hlaska: String?
    @Published var rezimPoznamky = false
    var naNota: ((NotaCil) -> Void)?
    @Published var nalezeno = 0
    @Published var aktualni = 0
    private var vysledky: [PDFSelection] = []

    var dokument: PDFDocument? { pdfView?.document }

    /// Hledá v dokumentu; s `naStrane` skočí na první nález na dané straně (jinak na první nález).
    func hledej(_ text: String, naStrane: Int? = nil) {
        guard let pdfView = pdfView, let dokument = pdfView.document else { return }
        let hledany = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !hledany.isEmpty else { zrus(); return }
        vysledky = dokument.findString(hledany, withOptions: [.caseInsensitive, .diacriticInsensitive])
        vysledky.forEach { $0.color = UIColor.yellow }
        pdfView.highlightedSelections = vysledky
        nalezeno = vysledky.count
        aktualni = 0
        if let strana = naStrane,
           let i = vysledky.firstIndex(where: { v in v.pages.contains { dokument.index(for: $0) == strana } }) {
            aktualni = i
        }
        ukaz()
    }

    func zrus() {
        vysledky = []
        nalezeno = 0
        aktualni = 0
        pdfView?.highlightedSelections = nil
        pdfView?.clearSelection()
    }

    func dalsi() { posun(1) }
    func predchozi() { posun(-1) }

    private func posun(_ krok: Int) {
        guard !vysledky.isEmpty else { return }
        aktualni = (aktualni + krok + vysledky.count) % vysledky.count
        ukaz()
    }

    // MARK: - zoom

    func priblizit() { zoom(1.25) }
    func oddalit() { zoom(0.8) }

    private func zoom(_ faktor: CGFloat) {
        guard let v = pdfView else { return }
        v.autoScales = false
        v.scaleFactor = min(max(v.scaleFactor * faktor, v.minScaleFactor), v.maxScaleFactor)
        ulozZoom()
    }

    func naSirku() {
        pdfView?.autoScales = true
        UserDefaults.standard.removeObject(forKey: Stav.klicZoom)
    }

    /// Dvojklepnutí: přepíná mezi šířkou stránky a 200 %.
    func prepniZoom() {
        guard let v = pdfView else { return }
        if v.autoScales {
            v.autoScales = false
            v.scaleFactor = min(max(v.scaleFactorForSizeToFit * 2, v.minScaleFactor), v.maxScaleFactor)
            ulozZoom()
        } else {
            naSirku()
        }
    }

    /// Klepnutí na okraj: předchozí / další stránka.
    func listuj(_ krok: Int) {
        guard let v = pdfView, let doc = v.document, let page = v.currentPage else { return }
        let i = doc.index(for: page) + krok
        guard i >= 0, i < doc.pageCount, let cil = doc.page(at: i) else { return }
        v.go(to: cil)
    }

    fileprivate func ulozZoom() {
        guard let v = pdfView, !v.autoScales else { return }
        UserDefaults.standard.set(Double(v.scaleFactor), forKey: Stav.klicZoom)
    }

    // MARK: - záložky a přechody

    func jdiNaStranu(_ index: Int) {
        guard let doc = pdfView?.document, index >= 0, index < doc.pageCount, let page = doc.page(at: index) else { return }
        pdfView?.go(to: page)
    }

    func pocetStran() -> Int { pdfView?.document?.pageCount ?? 0 }

    // MARK: - anotace (zvýraznění a poznámky)

    func zvyrazni(_ barva: UIColor) {
        guard let v = pdfView, let vyber = v.currentSelection else {
            ukazHlasku("Nejdřív dlouze podrž prst na textu a označ ho.")
            return
        }
        for radek in vyber.selectionsByLine() {
            for page in radek.pages {
                let b = radek.bounds(for: page)
                guard b.width > 1, b.height > 1 else { continue }
                let a = PDFAnnotation(bounds: b, forType: .highlight, withProperties: nil)
                a.markupType = .highlight
                a.color = barva.withAlphaComponent(0.5)
                a.quadrilateralPoints = [
                    NSValue(cgPoint: CGPoint(x: 0, y: b.height)), NSValue(cgPoint: CGPoint(x: b.width, y: b.height)),
                    NSValue(cgPoint: CGPoint(x: 0, y: 0)), NSValue(cgPoint: CGPoint(x: b.width, y: 0))
                ]
                page.addAnnotation(a)
            }
        }
        v.clearSelection()
        uloz()
    }

    func zacniPoznamku() {
        rezimPoznamky = true
        ukazHlasku("Klepni na místo, kam chceš poznámku.")
    }

    func ulozPoznamku(_ cil: NotaCil, text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let a = cil.anotace {
            if t.isEmpty { cil.strana.removeAnnotation(a) } else { a.contents = t }
        } else if !t.isEmpty {
            let a = PDFAnnotation(bounds: CGRect(x: cil.bod.x, y: cil.bod.y - 24, width: 24, height: 24),
                                  forType: .text, withProperties: nil)
            a.iconType = .note
            a.color = UIColor(red: 1, green: 0.8, blue: 0.1, alpha: 1)
            a.contents = t
            cil.strana.addAnnotation(a)
        }
        uloz()
        objectWillChange.send()
    }

    func smaz(_ a: PDFAnnotation, na page: PDFPage) {
        page.removeAnnotation(a)
        uloz()
        objectWillChange.send()
    }

    /// Zvýraznění a poznámky ze všech stran dokumentu.
    func polozky() -> [PolozkaAnotace] {
        guard let doc = pdfView?.document else { return [] }
        var vysl: [PolozkaAnotace] = []
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            for a in page.annotations {
                let typ = (a.type ?? "").replacingOccurrences(of: "/", with: "")
                guard typ == "Highlight" || typ == "Text" else { continue }
                vysl.append(PolozkaAnotace(anotace: a, strana: page, index: i, poznamka: typ == "Text"))
            }
        }
        return vysl
    }

    /// Zapíše PDF i s anotacemi zpět do souboru v zařízení (přes dočasný soubor).
    func uloz() {
        guard let doc = pdfView?.document, let url = soubor else { return }
        let tmp = url.deletingLastPathComponent().appendingPathComponent(url.lastPathComponent + ".tmp")
        try? FileManager.default.removeItem(at: tmp)
        guard doc.write(to: tmp) else { ukazHlasku("Uložení změn do PDF se nepovedlo."); return }
        do { _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp) }
        catch { ukazHlasku("Uložení změn do PDF se nepovedlo.") }
    }

    func ukazHlasku(_ text: String) {
        hlaska = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if self?.hlaska == text { self?.hlaska = nil }
        }
    }

    private func ukaz() {
        guard aktualni < vysledky.count, let pdfView = pdfView else { return }
        let v = vysledky[aktualni]
        pdfView.setCurrentSelection(v, animate: true)
        pdfView.go(to: v)
    }
}

struct PolozkaAnotace: Identifiable {
    let anotace: PDFAnnotation
    let strana: PDFPage
    let index: Int
    let poznamka: Bool
    var id: ObjectIdentifier { ObjectIdentifier(anotace) }

    var text: String {
        if poznamka { return anotace.contents ?? "" }
        return strana.selection(for: anotace.bounds)?.string?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

/// Zobrazí PDF ze souboru, pamatuje si stranu a umí sépiový / tmavý režim.
struct PDFViewerView: UIViewRepresentable {
    let url: URL
    let cisloID: String
    let rezim: RezimCteni
    let ovladac: PDFOvladac
    var pocatecniStrana: Int? = nil

    func makeCoordinator() -> Coordinator { Coordinator(cisloID: cisloID, ovladac: ovladac) }

    func makeUIView(context: Context) -> UIView {
        let kontejner = UIView()
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .white
        view.maxScaleFactor = 4
        view.document = PDFDocument(url: url)
        view.translatesAutoresizingMaskIntoConstraints = false
        kontejner.addSubview(view)

        let filtr = UIView()
        filtr.isUserInteractionEnabled = false
        filtr.translatesAutoresizingMaskIntoConstraints = false
        kontejner.addSubview(filtr)

        for v in [view, filtr] {
            NSLayoutConstraint.activate([
                v.leadingAnchor.constraint(equalTo: kontejner.leadingAnchor),
                v.trailingAnchor.constraint(equalTo: kontejner.trailingAnchor),
                v.topAnchor.constraint(equalTo: kontejner.topAnchor),
                v.bottomAnchor.constraint(equalTo: kontejner.bottomAnchor)
            ])
        }

        let c = context.coordinator
        c.filtr = filtr
        c.pdfView = view
        ovladac.pdfView = view
        ovladac.soubor = url

        // obnovení strany, kde čtenář skončil
        if let strana = pocatecniStrana ?? Stav.pozice(cisloID), let doc = view.document, strana < doc.pageCount,
           let page = doc.page(at: strana) {
            DispatchQueue.main.async { view.go(to: page) }
        }
        // obnovení zoomu, pokud ho čtenář dřív nastavil ručně
        let zoom = UserDefaults.standard.double(forKey: Stav.klicZoom)
        if zoom > 0 {
            DispatchQueue.main.async {
                view.autoScales = false
                view.scaleFactor = min(max(CGFloat(zoom), view.minScaleFactor), view.maxScaleFactor)
            }
        }
        let klepnuti = UITapGestureRecognizer(target: c, action: #selector(Coordinator.klepnuti(_:)))
        klepnuti.delegate = c
        let dvojklepnuti = UITapGestureRecognizer(target: c, action: #selector(Coordinator.dvojklepnuti(_:)))
        dvojklepnuti.numberOfTapsRequired = 2
        dvojklepnuti.delegate = c
        klepnuti.require(toFail: dvojklepnuti)
        view.addGestureRecognizer(dvojklepnuti)
        view.addGestureRecognizer(klepnuti)
        NotificationCenter.default.addObserver(c, selector: #selector(Coordinator.zmenaZoomu),
                                               name: .PDFViewScaleChanged, object: view)
        NotificationCenter.default.addObserver(c, selector: #selector(Coordinator.zmenaStrany),
                                               name: .PDFViewPageChanged, object: view)
        nastavRezim(filtr)
        return kontejner
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let filtr = context.coordinator.filtr { nastavRezim(filtr) }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.ulozStranu()
        NotificationCenter.default.removeObserver(coordinator)
    }

    /// Průhledná vrstva přes PDF: rozdíl s bílou = inverze, násobení = sépie.
    private func nastavRezim(_ filtr: UIView) {
        switch rezim {
        case .normalni:
            filtr.isHidden = true
            filtr.layer.compositingFilter = nil
        case .sepie:
            filtr.isHidden = false
            filtr.backgroundColor = UIColor(red: 0.96, green: 0.90, blue: 0.75, alpha: 1)
            filtr.layer.compositingFilter = "multiplyBlendMode"
        case .tmavy:
            filtr.isHidden = false
            filtr.backgroundColor = .white
            filtr.layer.compositingFilter = "differenceBlendMode"
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let cisloID: String
        let ovladac: PDFOvladac
        weak var pdfView: PDFView?
        weak var filtr: UIView?
        init(cisloID: String, ovladac: PDFOvladac) {
            self.cisloID = cisloID
            self.ovladac = ovladac
        }

        @objc func zmenaStrany() { ulozStranu() }
        @objc func zmenaZoomu() { ovladac.ulozZoom() }

        func ulozStranu() {
            guard let doc = pdfView?.document, let page = pdfView?.currentPage else { return }
            let i = doc.index(for: page)
            Stav.ulozPozici(cisloID, i)
            if ovladac.strana != i { DispatchQueue.main.async { self.ovladac.strana = i } }
        }

        /// V režimu poznámky založí novou; jinak klepnutí na ikonu poznámky otevře její úpravu.
        @objc func klepnuti(_ g: UITapGestureRecognizer) {
            guard let v = pdfView else { return }
            let p = g.location(in: v)
            guard let page = v.page(for: p, nearest: ovladac.rezimPoznamky) else { return }
            let bod = v.convert(p, to: page)
            if ovladac.rezimPoznamky {
                ovladac.rezimPoznamky = false
                ovladac.naNota?(NotaCil(strana: page, bod: bod, anotace: nil))
            } else if let a = page.annotation(at: bod),
                      (a.type ?? "").replacingOccurrences(of: "/", with: "") == "Text" {
                ovladac.naNota?(NotaCil(strana: page, bod: bod, anotace: a))
            } else if v.currentSelection == nil {
                // okraje (~20 % šířky) listují; označený text klepnutí jen zruší výběr
                let podil = p.x / max(v.bounds.width, 1)
                if podil < 0.2 { ovladac.listuj(-1) } else if podil > 0.8 { ovladac.listuj(1) }
            }
        }

        @objc func dvojklepnuti(_ g: UITapGestureRecognizer) {
            guard !ovladac.rezimPoznamky else { return }
            ovladac.prepniZoom()
        }

        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }
}
