import SwiftUI
import UIKit

extension Cislo {
    /// Veřejný odkaz na PDF čísla na webu (sdílí se odkaz, ne místní soubor s vlastními poznámkami).
    var odkaz: URL? { Config.adresy.first.flatMap { URL(string: $0 + pdf) } }

    /// Rok vydání z `poradi` (RRRRMM).
    var rok: Int { poradi / 100 }
}

/// Systémové sdílecí okno (ShareLink je až od iOS 16).
struct SdileniSheet: UIViewControllerRepresentable {
    let cislo: Cislo

    func makeUIViewController(context: Context) -> UIActivityViewController {
        var polozky: [Any] = ["Mimoník – \(cislo.nazev)"]
        if let url = cislo.odkaz { polozky.append(url) }
        return UIActivityViewController(activityItems: polozky, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Filtr seznamu čísel na domovské obrazovce.
enum FiltrSeznamu: String, CaseIterable, Identifiable {
    case vse, neprectena, oblibena
    var id: String { rawValue }
    var nazev: String {
        switch self {
        case .vse: return "Všechna čísla"
        case .neprectena: return "Nepřečtená"
        case .oblibena: return "Oblíbená"
        }
    }
}
