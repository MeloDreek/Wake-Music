import Foundation

// Compiled alongside the production EmptyContentLayout enum. UIKit's content
// fitting remains covered by the Duo/iPad/Mac UI smoke test, not a mock layout.
@main
enum EmptyContentLayoutTests {
    static func main() {
        var checks = 0
        for bounds: CGFloat in [0, 44, 118, 240, 390, 600, 844, 1200] {
            for leading: CGFloat in [0, 20, 96, 160] {
                for trailing: CGFloat in [0, 34, 90, 160] {
                    let viewport = EmptyContentLayout.availableLength(bounds, leading: leading, trailing: trailing)
                    precondition(viewport.isFinite && viewport >= 0)
                    precondition(viewport == max(0, bounds - leading - trailing))
                    for content: CGFloat in [320, 480, 720, 1200] {
                        let height = EmptyContentLayout.height(viewport: viewport, content: content)
                        precondition(height.isFinite && height > 0)
                        precondition(height >= content, "Short windows must scroll, not crop controls")
                        precondition(height >= viewport, "Empty content must fill the visible viewport")
                        checks += 3
                    }
                    checks += 2
                }
            }
        }
        let duoTransition = EmptyContentLayout.availableLength(180, leading: 96, trailing: 202)
        precondition(duoTransition == 0)
        precondition(EmptyContentLayout.height(viewport: duoTransition, content: 480) == 480)
        precondition(EmptyContentLayout.height(viewport: .nan, content: .infinity) == 1)
        precondition(EmptyContentLayout.availableLength(.infinity, leading: 0, trailing: 0) == 0)
        print("PASS_EMPTY_CONTENT_LAYOUT \(checks + 4) checks")
    }
}
