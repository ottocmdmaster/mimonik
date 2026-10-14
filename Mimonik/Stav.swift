import Foundation

/// Stav čtení (přečtené, pozice, oblíbené) uložený v UserDefaults.
enum Stav {
    /// Pošle se po každé změně, aby se překreslily seznamy.
    static let zmena = Notification.Name("tl.knyt.Mimonik.stavZmena")

    private static let klicPrectena = "prectenaCisla"
    private static let klicOblibena = "oblibenaCisla"
    private static let klicPozice = "poziceCisel"
    /// Úložiště; testy ho nahrazují vlastním.
    static var d = UserDefaults.standard

    static func jePrectene(_ id: String) -> Bool {
        (d.stringArray(forKey: klicPrectena) ?? []).contains(id)
    }

    static func oznacPrectene(_ id: String) {
        var s = d.stringArray(forKey: klicPrectena) ?? []
        guard !s.contains(id) else { return }
        s.append(id)
        d.set(s, forKey: klicPrectena)
        NotificationCenter.default.post(name: zmena, object: nil)
    }

    static func pocetNeprectenych(_ cisla: [Cislo]) -> Int {
        let s = Set(d.stringArray(forKey: klicPrectena) ?? [])
        return cisla.filter { !s.contains($0.id) }.count
    }

    static func pozice(_ id: String) -> Int? {
        (d.dictionary(forKey: klicPozice) as? [String: Int])?[id]
    }

    static func ulozPozici(_ id: String, _ strana: Int) {
        var p = (d.dictionary(forKey: klicPozice) as? [String: Int]) ?? [:]
        p[id] = strana
        d.set(p, forKey: klicPozice)
        zaznamenejStranu(id, strana)
    }

    static func jePoblibene(_ id: String) -> Bool {
        (d.stringArray(forKey: klicOblibena) ?? []).contains(id)
    }

    static func prepniOblibene(_ id: String) {
        var s = d.stringArray(forKey: klicOblibena) ?? []
        if let i = s.firstIndex(of: id) { s.remove(at: i) } else { s.append(id) }
        d.set(s, forKey: klicOblibena)
        NotificationCenter.default.post(name: zmena, object: nil)
    }

    // MARK: - záložky na stránky

    private static let klicZalozky = "zalozkyStran"

    static func zalozky(_ id: String) -> [Int] {
        ((d.dictionary(forKey: klicZalozky) as? [String: [Int]])?[id] ?? []).sorted()
    }

    static func jeZalozka(_ id: String, _ strana: Int) -> Bool {
        zalozky(id).contains(strana)
    }

    /// Přidá nebo odebere záložku; vrací, jestli po změně existuje.
    @discardableResult
    static func prepniZalozku(_ id: String, _ strana: Int) -> Bool {
        var vse = (d.dictionary(forKey: klicZalozky) as? [String: [Int]]) ?? [:]
        var z = vse[id] ?? []
        let existuje: Bool
        if let i = z.firstIndex(of: strana) { z.remove(at: i); existuje = false } else { z.append(strana); existuje = true }
        vse[id] = z
        d.set(vse, forKey: klicZalozky)
        return existuje
    }

    // MARK: - zobrazení (jas, zoom)

    static let klicJas = "jasCteni"
    static let klicZoom = "zoomCteni"

    // MARK: - pokračovat ve čtení

    private static let klicPosledni = "posledniOtevrene"

    /// Poslední číslo otevřené ve čtečce.
    static var posledniOtevrene: String? {
        get { d.string(forKey: klicPosledni) }
        set { d.set(newValue, forKey: klicPosledni) }
    }

    // MARK: - nastavení čtečky a seznamu

    static let klicSvitit = "nechatSvitit"
    static let klicVelikostSeznamu = "velikostSeznamu"

    /// Nezhasínat obrazovku při čtení (výchozí zapnuto).
    static var nechatSvitit: Bool {
        get { d.object(forKey: klicSvitit) as? Bool ?? true }
        set { d.set(newValue, forKey: klicSvitit) }
    }

    // MARK: - statistiky čtení

    private static let klicDoba = "dobaCteni"
    private static let klicOtevreni = "pocetOtevreni"
    private static let klicStrany = "otevreneStrany"

    /// Přičte dobu, po kterou byla čtečka čísla otevřená.
    static func pridejDobu(_ id: String, sekundy: Double) {
        guard sekundy > 0 else { return }
        var m = (d.dictionary(forKey: klicDoba) as? [String: Double]) ?? [:]
        m[id, default: 0] += sekundy
        d.set(m, forKey: klicDoba)
    }

    static func zaznamenejOtevreni(_ id: String) {
        var m = (d.dictionary(forKey: klicOtevreni) as? [String: Int]) ?? [:]
        m[id, default: 0] += 1
        d.set(m, forKey: klicOtevreni)
    }

    static func zaznamenejStranu(_ id: String, _ strana: Int) {
        var m = (d.dictionary(forKey: klicStrany) as? [String: [Int]]) ?? [:]
        var s = m[id] ?? []
        guard !s.contains(strana) else { return }
        s.append(strana)
        m[id] = s
        d.set(m, forKey: klicStrany)
    }

    struct Statistiky: Equatable {
        var prectenych = 0
        var celkem = 0
        var otevrenychStran = 0
        var sekundCteni: Double = 0
        var nejctenejsi: String?
    }

    /// Souhrn čtení. `nazvy` mapuje id čísla na název (pro nejčtenější číslo).
    static func statistiky(_ cisla: [Cislo]) -> Statistiky {
        let prectena = Set(d.stringArray(forKey: klicPrectena) ?? [])
        let doba = (d.dictionary(forKey: klicDoba) as? [String: Double]) ?? [:]
        let strany = (d.dictionary(forKey: klicStrany) as? [String: [Int]]) ?? [:]
        var s = Statistiky()
        s.celkem = cisla.count
        s.prectenych = cisla.filter { prectena.contains($0.id) }.count
        s.otevrenychStran = strany.values.reduce(0) { $0 + $1.count }
        s.sekundCteni = doba.values.reduce(0, +)
        if let nej = doba.max(by: { $0.value < $1.value }), nej.value > 0 {
            s.nejctenejsi = cisla.first { $0.id == nej.key }?.nazev
        }
        return s
    }

    /// „1 h 5 min“, „12 min“, „méně než minuta“.
    static func formatujDobu(_ sekundy: Double) -> String {
        let min = Int(sekundy / 60)
        if min >= 60 { return "\(min / 60) h \(min % 60) min" }
        return min > 0 ? "\(min) min" : "méně než minuta"
    }
}
