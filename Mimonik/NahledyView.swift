import SwiftUI
import PDFKit

/// Mřížka miniatur stran pro rychlé listování.
struct NahledyView: View {
    let dokument: PDFDocument?
    let aktualni: Int
    let vybrat: (Int) -> Void
    let zavrit: () -> Void

    private let sloupce = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: sloupce, spacing: 14) {
                        ForEach(0..<(dokument?.pageCount ?? 0), id: \.self) { i in
                            Button { vybrat(i); zavrit() } label: {
                                VStack(spacing: 4) {
                                    Nahled(strana: dokument?.page(at: i))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.accentColor, lineWidth: i == aktualni ? 3 : 0)
                                        )
                                    Text("\(i + 1)")
                                        .font(.caption)
                                        .fontWeight(i == aktualni ? .bold : .regular)
                                        .foregroundColor(i == aktualni ? .accentColor : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .id(i)
                        }
                    }
                    .padding(14)
                }
                .onAppear { proxy.scrollTo(aktualni, anchor: .center) }
            }
            .navigationTitle("Strany")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Hotovo", action: zavrit) } }
        }
        .navigationViewStyle(.stack)
    }
}

/// Jedna miniatura, vykreslí se až když se řádek objeví (LazyVGrid).
private struct Nahled: View {
    let strana: PDFPage?
    @State private var obrazek: UIImage?
    private static let cache = NSCache<NSString, UIImage>()

    var body: some View {
        Group {
            if let obrazek = obrazek {
                Image(uiImage: obrazek).resizable().scaledToFit()
            } else {
                Rectangle().fill(Color.gray.opacity(0.15)).aspectRatio(0.7, contentMode: .fit)
            }
        }
        .background(Color.white)
        .shadow(radius: 1.5)
        .task {
            guard let strana = strana, obrazek == nil else { return }
            let klic = "\(ObjectIdentifier(strana).hashValue)" as NSString
            if let c = Self.cache.object(forKey: klic) { obrazek = c; return }
            let o = strana.thumbnail(of: CGSize(width: 200, height: 280), for: .mediaBox)
            Self.cache.setObject(o, forKey: klic)
            obrazek = o
        }
    }
}
