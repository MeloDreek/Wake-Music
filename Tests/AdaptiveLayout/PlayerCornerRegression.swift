import UIKit

@main
enum PlayerCornerRegression {
    @MainActor
    static func main() {
        // A hidden window supplies UIKit's container geometry context. There is
        // no application scene in this command-line probe; never show the window.
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        let container = UIView(frame: window.bounds)
        container.clipsToBounds = true
        window.addSubview(container)
        defer { withExtendedLifetime(window) {} }
        let surface = UIView(frame: container.bounds)
        container.addSubview(surface)
        let probe = PlayerCornerProbe(surface: surface)

        precondition(!probe.shouldRoundTopCorners,
                     "iOS 26+ must bypass PanModal's uniform corner mask")
        probe.updatePresentationCorners()
        precondition(surface.clipsToBounds, "The presentation wrapper must clip its content")

        // Keep the same surface/configuration while the containing shape changes,
        // matching a presentation that remains open during folding or rotation.
        for (left, right): (Double, Double) in [(0, 50), (50, 50), (50, 0)] {
            container.cornerConfiguration = .corners(
                topLeftRadius: .fixed(left),
                topRightRadius: .fixed(right),
                bottomLeftRadius: .fixed(50),
                bottomRightRadius: .fixed(50)
            )
            container.setNeedsLayout()
            surface.setNeedsLayout()
            container.updatePropertiesIfNeeded()
            container.layoutIfNeeded()
            surface.layoutIfNeeded()

            let actual = [UIRectCorner.topLeft, .topRight, .bottomLeft, .bottomRight]
                .map { surface.effectiveRadius(corner: $0) }
            let expected = [CGFloat(left), CGFloat(right), 0, 0]
            for (actualRadius, expectedRadius) in zip(actual, expected) {
                precondition(abs(actualRadius - expectedRadius) < 0.01,
                             "Expected \(expected), got \(actual) after container change")
            }
        }

        // Reapplying the production configuration must retain the final geometry.
        probe.updatePresentationCorners()
        precondition(abs(surface.effectiveRadius(corner: .topLeft) - 50) < 0.01)
        precondition(surface.effectiveRadius(corner: .topRight) == 0)
        print("Passed 3 production corner transitions and wrapper clipping checks.")
    }
}
