import AppKit
import SwiftUI

/// Chrome-like pane: SwiftUI owns the content height, AppKit clamps the edges.
/// Fast fling keeps momentum and hard-stops — no rubber-band snap-back.
struct SteadyScrollView<Content: View>: View {
    var scrollToID: String?
    var scrollNonce: UInt = 0
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                content()
            }
            .scrollIndicators(.visible)
            .background(BounceOff())
            .onChange(of: scrollNonce) { _ in
                guard let scrollToID else { return }
                proxy.scrollTo(scrollToID)
            }
        }
    }
}

/// Walks up to the enclosing `NSScrollView` and turns elasticity off.
private struct BounceOff: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.isHidden = true
        DispatchQueue.main.async { disableBounce(from: view) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { disableBounce(from: view) }
    }

    private func disableBounce(from view: NSView) {
        var current: NSView? = view
        while let node = current {
            if let scroll = node as? NSScrollView {
                scroll.verticalScrollElasticity = .none
                scroll.horizontalScrollElasticity = .none
                return
            }
            current = node.superview
        }
    }
}
