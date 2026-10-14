import SwiftUI

/// Hustota a velikost písma v seznamu čísel.
enum VelikostSeznamu: String, CaseIterable, Identifiable {
    case kompaktni, normalni, velke
    var id: String { rawValue }
    var nazev: String {
        switch self {
        case .kompaktni: return "Kompaktní"
        case .normalni: return "Normální"
        case .velke: return "Velké"
        }
    }
    var pismo: Font {
        switch self {
        case .kompaktni: return .subheadline
        case .normalni: return .body
        case .velke: return .title3
        }
    }
    var odsazeni: CGFloat {
        switch self {
        case .kompaktni: return 0
        case .normalni: return 4
        case .velke: return 10
        }
    }
}
