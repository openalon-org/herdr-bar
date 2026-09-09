import AppKit
import HerdrCore
import SwiftUI

/// Two weights of the same `cpu` mark.
/// - `chrome`: SF Symbol only. Dashboard header must not compete with Working.
/// - `badge`: white plate + label-gray glyph (`AppIcon.icns`). About / Finder.
struct BrandMark: View {
    enum Style {
        case chrome
        case badge
    }

    var style: Style = .chrome
    var size: CGFloat = 28
    var opacity: Double = 1

    /// Light tile like cmux. Ink matches the dashboard header (`label` gray),
    /// not Working terracotta — that color stays on agent rows.
    static let plate = Color.white
    static let ink = Color(red: 58 / 255, green: 58 / 255, blue: 60 / 255)
    static let glyph = "cpu"
    static let glyphScale: CGFloat = 0.52
    /// Continuous-corner fraction close to macOS's app-icon squircle.
    static let cornerFraction: CGFloat = 0.223

    var body: some View {
        Group {
            switch style {
            case .chrome:
                Image(systemName: Self.glyph)
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: size, height: size)
            case .badge:
                badge
            }
        }
        .opacity(opacity)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var badge: some View {
        Group {
            if let icon = Self.bundleIcon() {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                ZStack {
                    Self.plate
                    Image(systemName: Self.glyph)
                        .font(.system(size: size * Self.glyphScale, weight: .semibold))
                        .foregroundStyle(Self.ink)
                        .symbolRenderingMode(.monochrome)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * Self.cornerFraction, style: .continuous))
    }

    static func bundleIcon() -> NSImage? {
        if let named = NSImage(named: "AppIcon"), named.size.width > 0 { return named }
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") {
            return NSImage(contentsOf: url)
        }
        guard LoginItem.isPackedApp(bundlePath: Bundle.main.bundlePath),
              let icon = NSApp.applicationIconImage,
              icon.size.width > 0
        else { return nil }
        return icon
    }
}
