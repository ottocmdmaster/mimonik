import Foundation

/// Stav čtení (přečtené, pozice, oblíbené) uložený v UserDefaults.
enum Stav {
    /// Pošle se po každé změně, aby se překreslily seznamy.
    static let zmena = Notification.Name("tl.knyt.Mimonik.stavZmena")

    private static let klicPrectena = "prectenaCisla"
    private static let klicOblibena = "oblibenaCisla"
    private static let klicPozice = "poziceCisel"
    private static let d = UserDefaults.standard

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
}
