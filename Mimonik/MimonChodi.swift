import SwiftUI

/// Mimoň chodí ze strany na stranu, dokud se číslo stahuje.
struct MimonChodi: View {
    private let vyska: CGFloat = 90
    private let rychlost: Double = 90  // bodů za sekundu

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { kontext in
                let sirka = max(geo.size.width - vyska * 0.6, 1)
                let t = kontext.date.timeIntervalSinceReferenceDate
                let cesta = sirka / rychlost
                let faze = t.truncatingRemainder(dividingBy: cesta * 2)
                let doprava = faze < cesta
                let pozice = (doprava ? faze : faze - cesta) / cesta
                let x = (doprava ? pozice : 1 - pozice) * sirka
                let krok = abs(sin(t * 9))
                Image("Mimon")
                    .resizable()
                    .scaledToFit()
                    .frame(height: vyska)
                    .scaleEffect(x: doprava ? 1 : -1, y: 1)
                    .rotationEffect(.degrees(sin(t * 9) * 6))
                    .offset(x: x, y: -krok * 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
        .frame(height: vyska + 12)
        .padding(.horizontal, 16)
    }
}
