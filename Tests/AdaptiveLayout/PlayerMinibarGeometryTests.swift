import Foundation
import CoreGraphics

@main
enum PlayerMinibarGeometryTests {
    static func main() {
        var count = 0
        func check(_ name: String, bounds: CGRect, safe: CGRect, bar: CGRect? = nil,
            expected: CGRect?) {
            let actual = PlayerMinibarGeometry.frame(in: bounds, safeFrame: safe,
                barFrame: bar, height: 60, gap: 5)
            precondition(actual == expected, "\(name): \(String(describing: actual)) != \(String(describing: expected))")
            if let actual {
                precondition(actual.width >= 0 && actual.height >= 0)
                precondition(actual.minX >= bounds.minX && actual.maxX <= bounds.maxX)
                precondition(actual.minY >= bounds.minY && actual.maxY <= bounds.maxY)
            }
            count += 1
        }
        let phone = CGRect(x: 0, y: 0, width: 390, height: 844)
        let phoneSafe = CGRect(x: 0, y: 59, width: 390, height: 751)
        check("home indicator without tab bar", bounds: phone, safe: phoneSafe,
            expected: CGRect(x: 0, y: 745, width: 390, height: 60))
        check("bottom tab bar", bounds: phone, safe: phoneSafe,
            bar: CGRect(x: 0, y: 761, width: 390, height: 83),
            expected: CGRect(x: 0, y: 696, width: 390, height: 60))
        check("floating bottom tab bar", bounds: phone, safe: phoneSafe,
            bar: CGRect(x: 20, y: 751, width: 350, height: 54),
            expected: CGRect(x: 0, y: 686, width: 390, height: 60))
        let wide = CGRect(x: 0, y: 0, width: 900, height: 600)
        let wideSafe = CGRect(x: 24, y: 30, width: 816, height: 550)
        check("left vertical rail", bounds: wide, safe: wideSafe,
            bar: CGRect(x: 0, y: 40, width: 88, height: 500),
            expected: CGRect(x: 88, y: 515, width: 752, height: 60))
        check("right vertical rail RTL", bounds: wide, safe: wideSafe,
            bar: CGRect(x: 800, y: 40, width: 100, height: 500),
            expected: CGRect(x: 24, y: 515, width: 776, height: 60))
        check("top tab bar never lifts mini player", bounds: wide, safe: wideSafe,
            bar: CGRect(x: 200, y: 20, width: 500, height: 55),
            expected: CGRect(x: 24, y: 515, width: 816, height: 60))
        check("asymmetric notch only", bounds: wide, safe: wideSafe,
            expected: CGRect(x: 24, y: 515, width: 816, height: 60))
        check("already inset past side bar, no double inset", bounds: wide,
            safe: CGRect(x: 100, y: 30, width: 740, height: 550),
            bar: CGRect(x: 0, y: 40, width: 88, height: 500),
            expected: CGRect(x: 100, y: 515, width: 740, height: 60))
        check("bar outside this controller", bounds: wide, safe: wideSafe,
            bar: CGRect(x: -100, y: 0, width: 88, height: 600),
            expected: CGRect(x: 24, y: 515, width: 816, height: 60))
        check("tiny transition viewport", bounds: CGRect(x: 0, y: 0, width: 100, height: 30),
            safe: CGRect(x: 0, y: 10, width: 100, height: 20),
            expected: CGRect(x: 0, y: 10, width: 100, height: 15))
        check("temporary zero bounds", bounds: .zero, safe: .zero, expected: nil)
        check("temporary empty safe frame", bounds: wide, safe: .zero, expected: nil)
        check("bar consumes remaining height", bounds: CGRect(x: 0, y: 0, width: 200, height: 50),
            safe: CGRect(x: 0, y: 20, width: 200, height: 30),
            bar: CGRect(x: 0, y: 20, width: 200, height: 30),
            expected: CGRect(x: 0, y: 20, width: 200, height: 0))
        print("Passed \(count) PlayerMinibarGeometry regressions")
    }
}
