import Foundation

@main
enum PlayerLayoutRegression {
    static func main() {
        let cases: [(String, CGSize, Bool, Bool, Bool, Bool, Bool)] = [
            ("phone portrait", CGSize(width: 430, height: 932), true, false, false, false, false),
            ("phone landscape", CGSize(width: 810, height: 430), true, false, true, true, false),
            ("phone landscape with regular width", CGSize(width: 850, height: 430), true, true, true, true, false),
            ("expanded phone", CGSize(width: 900, height: 760), true, true, false, false, true),
            ("expanded phone portrait", CGSize(width: 760, height: 900), true, true, false, false, true),
            ("folded phone", CGSize(width: 420, height: 850), true, false, false, false, false),
            ("narrow split", CGSize(width: 600, height: 900), false, true, false, false, false),
            ("tablet landscape", CGSize(width: 1100, height: 760), false, true, false, false, true),
            ("empty layout pass", CGSize(width: 0, height: 0), true, false, true, false, false)
        ]
        for (name, size, phone, regular, compact, expectedCompact, expectedColumns) in cases {
            let result = PlayerViewportLayout(size: size, isPhone: phone,
                                             horizontalIsRegular: regular, verticalIsCompact: compact)
            precondition(result.isCompactLandscape == expectedCompact, "\(name): wrong compact mode")
            precondition(result.usesTwoColumns == expectedColumns, "\(name): wrong column count")
        }
        print("Passed \(cases.count) player viewport cases.")
    }
}
