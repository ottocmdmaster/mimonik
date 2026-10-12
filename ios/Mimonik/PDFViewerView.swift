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

/// Drží PDFView a výsledky hledání, aby je mohl ovládat toolbar.
final class PDFOvladac: ObservableObject {
    fileprivate weak var pdfView: PDFView?
    @Published var nalezeno = 0
    @Published var aktualni = 0
    private var vysledky: [PDFSelection] = []

    func hledej(_ text: String) {
        guard let pdfView = pdfView, let dokument = pdfView.document else { return }
        let hledany = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !hledany.isEmpty else { zrus(); return }
        vysledky = dokument.findString(hledany, withOptions: [.caseInsensitive, .diacriticInsensitive])
        vysledky.forEach { $0.color = UIColor.yellow }
        pdfView.highlightedSelections = vysledky
        nalezeno = vysledky.count
        aktualni = 0
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

    private func ukaz() {
        guard aktualni < vysledky.count, let pdfView = pdfView else { return }
        let v = vysledky[aktualni]
        pdfView.setCurrentSelection(v, animate: true)
        pdfView.go(to: v)
    }
}

/// Zobrazí PDF ze souboru, pamatuje si stranu a umí sépiový / tmavý režim.
struct PDFViewerView: UIViewRepresentable {
    let url: URL
    let cisloID: String
    let rezim: RezimCteni
    let ovladac: PDFOvladac

    func makeCoordinator() -> Coordinator { Coordinator(cisloID: cisloID) }

    func makeUIView(context: Context) -> UIView {
        let kontejner = UIView()
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .white
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

        // obnovení strany, kde čtenář skončil
        if let strana = Stav.pozice(cisloID), let doc = view.document, strana < doc.pageCount,
           let page = doc.page(at: strana) {
            DispatchQueue.main.async { view.go(to: page) }
        }
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

    final class Coordinator: NSObject {
        let cisloID: String
        weak var pdfView: PDFView?
        weak var filtr: UIView?
        init(cisloID: String) { self.cisloID = cisloID }

        @objc func zmenaStrany() { ulozStranu() }

        func ulozStranu() {
            guard let doc = pdfView?.document, let page = pdfView?.currentPage else { return }
            Stav.ulozPozici(cisloID, doc.index(for: page))
        }
    }
}
