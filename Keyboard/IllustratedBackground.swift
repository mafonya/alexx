import SwiftUI
import UIKit

extension View {
    func illustratedBackground() -> some View {
        modifier(IllustratedBackground())
    }
}

struct IllustratedBackground: ViewModifier {
    static let clearPreferenceKey = "clearIllustratedBackground"

    @AppStorage(Self.clearPreferenceKey) private var isClear = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(isClear ? .automatic : .hidden)
            .background {
                if !isClear {
                    artwork
                        .ignoresSafeArea(.container)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
    }

    private var artwork: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let bandHeight = geometry.size.height / 3
            let overlap = min(24, bandHeight / 4)
            ZStack(alignment: .top) {
                scene("FoxyKitesurfing", focus: 0.47, width: width, height: bandHeight + overlap)
                scene("FoxySnowboarding", focus: 0.69, width: width, height: bandHeight + 2 * overlap)
                    .mask(alignment: .top) { fadeIn(length: 2 * overlap) }
                    .offset(y: bandHeight - overlap)
                scene("FoxyTennis", focus: 0.75, width: width, height: bandHeight + overlap)
                    .mask(alignment: .top) { fadeIn(length: 2 * overlap) }
                    .offset(y: 2 * bandHeight - overlap)
            }
            .frame(width: width, height: geometry.size.height, alignment: .top)
            .overlay {
                Color(uiColor: .systemBackground)
                    .opacity(reduceTransparency ? 0.82 : colorScheme == .dark ? 0.58 : 0.42)
            }
        }
    }

    private func fadeIn(length: CGFloat) -> some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: length)
            Color.black
        }
    }

    private func scene(_ name: String, focus: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        // All three source illustrations are portrait images with a 2:3 aspect ratio.
        let imageHeight = max(height, width * 1.5)
        return Image(name)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: imageHeight)
            .offset(y: -(imageHeight - height) * focus)
            .frame(width: width, height: height, alignment: .top)
            .clipped()
    }
}
