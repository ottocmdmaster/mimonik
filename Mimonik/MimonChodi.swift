import SwiftUI

/// Vzhled mimoně: základní, nebo s doplňkem nakresleným přes obrázek.
enum MimonVarianta: CaseIterable {
    case zakladni, bryle, cepice, motylek

    static func nahodna() -> MimonVarianta { allCases.randomElement() ?? .zakladni }
}

/// Mimoň s doplňkem. Souřadnice doplňků jsou v poměru k výšce a šířce obrázku.
struct MimonObrazek: View {
    let varianta: MimonVarianta
    let vyska: CGFloat
    private var sirka: CGFloat { vyska * 227 / 400 }

    var body: some View {
        ZStack {
            Image("Mimon").resizable().scaledToFit()
            switch varianta {
            case .zakladni:
                EmptyView()
            case .bryle:
                // sluneční brýle přes oči
                Capsule().fill(Color.black.opacity(0.88))
                    .frame(width: sirka * 0.68, height: vyska * 0.15)
                    .position(x: sirka * 0.51, y: vyska * 0.275)
                Capsule().fill(Color.white.opacity(0.35))
                    .frame(width: sirka * 0.12, height: vyska * 0.03)
                    .position(x: sirka * 0.32, y: vyska * 0.24)
            case .cepice:
                // červená kšiltovka
                Capsule().fill(Color.red)
                    .frame(width: sirka * 0.62, height: vyska * 0.10)
                    .position(x: sirka * 0.5, y: vyska * 0.115)
                Capsule().fill(Color(red: 0.7, green: 0, blue: 0))
                    .frame(width: sirka * 0.36, height: vyska * 0.04)
                    .position(x: sirka * 0.74, y: vyska * 0.16)
            case .motylek:
                // červený motýlek pod pusou
                Capsule().fill(Color.red)
                    .frame(width: sirka * 0.30, height: vyska * 0.06)
                    .position(x: sirka * 0.5, y: vyska * 0.50)
                Circle().fill(Color(red: 0.7, green: 0, blue: 0))
                    .frame(width: vyska * 0.045)
                    .position(x: sirka * 0.5, y: vyska * 0.50)
            }
        }
        .frame(width: sirka, height: vyska)
    }
}

/// Mimoň chodí ze strany na stranu, dokud se číslo stahuje; po stažení zamává.
struct MimonChodi: View {
    var varianta: MimonVarianta = .zakladni
    var zamava = false
    private let vyska: CGFloat = 90
    private let rychlost: Double = 90  // bodů za sekundu

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { kontext in
                let sirka = max(geo.size.width - vyska * 0.6, 1)
                let t = kontext.date.timeIntervalSinceReferenceDate
                if zamava {
                    ZStack(alignment: .topTrailing) {
                        MimonObrazek(varianta: varianta, vyska: vyska)
                            .rotationEffect(.degrees(sin(t * 12) * 8), anchor: .bottom)
                            .offset(y: -abs(sin(t * 6)) * 14)
                        Text("👋")
                            .font(.system(size: 30))
                            .rotationEffect(.degrees(sin(t * 16) * 25), anchor: .bottomLeading)
                            .offset(x: 26, y: -4)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                } else {
                    let cesta = sirka / rychlost
                    let faze = t.truncatingRemainder(dividingBy: cesta * 2)
                    let doprava = faze < cesta
                    let pozice = (doprava ? faze : faze - cesta) / cesta
                    let x = (doprava ? pozice : 1 - pozice) * sirka
                    let krok = abs(sin(t * 9))
                    MimonObrazek(varianta: varianta, vyska: vyska)
                        .scaleEffect(x: doprava ? 1 : -1, y: 1)
                        .rotationEffect(.degrees(sin(t * 9) * 6))
                        .offset(x: x, y: -krok * 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            }
        }
        .frame(height: vyska + 28)
        .padding(.horizontal, 16)
    }
}
