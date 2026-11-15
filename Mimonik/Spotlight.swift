import CoreSpotlight
import UniformTypeIdentifiers
import UIKit

/// Čísla ve vyhledávání iOS (Spotlight) a nabídka od Siri („Číst Mimoník“) po otevření čísla.
enum Spotlight {
    static let typAktivity = "cz.mimonik.cist"
    private static let domena = "cz.mimonik.cisla"

    static func indexuj(_ cisla: [Cislo]) {
        let polozky = cisla.map { c -> CSSearchableItem in
            let a = CSSearchableItemAttributeSet(contentType: .content)
            a.title = "Mimoník – \(c.nazev)"
            a.contentDescription = "Číst číslo \(c.nazev)"
            return CSSearchableItem(uniqueIdentifier: c.id, domainIdentifier: domena, attributeSet: a)
        }
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domena]) { _ in
            CSSearchableIndex.default().indexSearchableItems(polozky)
        }
    }

    /// Nastaví aktivitu čtení čísla (hledání + návrh Siri).
    static func nastav(_ a: NSUserActivity, _ c: Cislo) {
        a.title = "Číst Mimoník \(c.nazev)"
        a.userInfo = ["id": c.id]
        a.isEligibleForSearch = true
        a.isEligibleForPrediction = true
        a.persistentIdentifier = c.id
    }

    /// Id čísla z aktivity (Spotlight nebo Siri), jinak nil.
    static func id(z a: NSUserActivity) -> String? {
        if a.activityType == CSSearchableItemActionType {
            return a.userInfo?[CSSearchableItemActivityIdentifier] as? String
        }
        return a.userInfo?["id"] as? String
    }
}
