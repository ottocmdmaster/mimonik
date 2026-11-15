import Foundation

/// Synchronizace stavu čtení (přečtené, oblíbené, záložky, pozice) mezi zařízeními přes iCloud.
/// U každé položky vyhrává novější změna; při prvním propojení se místní a iCloudová data sloučí.
enum Sync {
    static let klice = ["prectenaCisla", "oblibenaCisla", "zalozkyStran", "poziceCisel"]
    private static var kv: NSUbiquitousKeyValueStore { .default }
    private static func casKlic(_ k: String) -> String { "cas_" + k }

    /// Jen pro skutečné úložiště appky (testy si Stav.d nahrazují vlastním).
    private static var aktivni: Bool { Stav.d === UserDefaults.standard }

    static func start() {
        guard aktivni else { return }
        NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                               object: kv, queue: .main) { n in
            let zmenene = n.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? klice
            prijmi(zmenene)
        }
        kv.synchronize()
        prijmi(klice)
        for k in klice where kv.object(forKey: k) == nil && Stav.d.object(forKey: k) != nil { odesli(k) }
    }

    /// Zavolá se po každé místní změně synchronizované položky.
    static func odesli(_ klic: String) {
        guard aktivni, klice.contains(klic) else { return }
        let ted = Date().timeIntervalSince1970
        Stav.d.set(ted, forKey: casKlic(klic))
        if let h = Stav.d.object(forKey: klic) { kv.set(h, forKey: klic) } else { kv.removeObject(forKey: klic) }
        kv.set(ted, forKey: casKlic(klic))
        kv.synchronize()
    }

    private static func prijmi(_ zmenene: [String]) {
        var zmena = false
        for k in zmenene where klice.contains(k) {
            let vzdaleny = kv.double(forKey: casKlic(k))
            let mistni = Stav.d.double(forKey: casKlic(k))
            guard vzdaleny > mistni, let h = kv.object(forKey: k) else { continue }
            if mistni == 0, let sloucene = slouc(Stav.d.object(forKey: k), h) {
                // první propojení: nic se neztratí, místní data se přidají k iCloudovým
                Stav.d.set(sloucene, forKey: k)
                odesli(k)
            } else {
                Stav.d.set(h, forKey: k)
                Stav.d.set(vzdaleny, forKey: casKlic(k))
            }
            zmena = true
        }
        if zmena { NotificationCenter.default.post(name: Stav.zmena, object: nil) }
    }

    /// Sloučení dvou hodnot stejného typu; nil, když se sloučit nedají nebo místní hodnota chybí.
    static func slouc(_ misto: Any?, _ vzdalene: Any) -> Any? {
        switch (misto, vzdalene) {
        case let (a as [String], b as [String]):
            return a + b.filter { !a.contains($0) }
        case let (a as [String: [Int]], b as [String: [Int]]):
            return a.merging(b) { Array(Set($0 + $1)).sorted() }
        case let (a as [String: Int], b as [String: Int]):
            return a.merging(b) { max($0, $1) }
        default:
            return nil
        }
    }
}
