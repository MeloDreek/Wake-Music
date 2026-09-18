import UIKit

// run-price-cell-layout.sh compiles the real cell with these narrow test doubles.
private let appMainColor = UIColor.label
private enum PurchaseStoreID: String {
    case lifetime198 = "com.OfflineMusic.www.lifetime198"
}
private struct StoreProduct {
    let productIdentifier: String
    let paywallTitle: String
    let localizedPriceString: String
}
private var usesChineseRecommendation = false
private extension String {
    func localStr() -> String {
        self == "Purchase.BestChoice" ? (usesChineseRecommendation ? "最推荐" : "Most Recommended") : self
    }
}

@main
private enum PriceCellLayoutProbe {
    @MainActor static func main() {
        var assertions = 0
        func check(_ result: @autoclosure () -> Bool, _ message: String) {
            assertions += 1
            precondition(result(), message)
        }
        func labels(in view: UIView) -> [UILabel] {
            (view as? UILabel).map { [$0] } ?? view.subviews.flatMap { labels(in: $0) }
        }
        func isVisible(_ view: UIView) -> Bool {
            !view.isHidden && (view.superview.map { isVisible($0) } ?? true)
        }
        func size(_ cell: PurchasePriceCell, width: CGFloat) -> CGFloat {
            cell.frame = CGRect(x: 0, y: 0, width: width, height: 2_000)
            cell.setNeedsLayout()
            cell.layoutIfNeeded()
            let fitting = cell.contentView.systemLayoutSizeFitting(
                CGSize(width: width, height: 0),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            )
            cell.frame.size.height = ceil(fitting.height)
            cell.setNeedsLayout()
            cell.layoutIfNeeded()
            return fitting.height
        }

        let cases: [(String, String, String?, Bool)] = [
            ("Monthly Premium", "US$1.99", nil, false),
            ("Annual Premium", "US$7.99", "US$0.67 / month", false),
            ("Lifetime Premium", "US$19.99", nil, true),
            ("家庭共享终身高级版", "US$39.99", nil, false),
            ("Monatliche Premium-Mitgliedschaft", "1.999,99 €", "3 Tage kostenlos testen", false),
            ("Premium für die ganze Familie auf Lebenszeit", "1.999,99 €", nil, false),
            ("اشتراك بريميوم السنوي", "١٩٩٫٩٩ ر.س.", "تجربة مجانية لمدة ٣ أيام", false)
        ]
        for width: CGFloat in [256, 320, 360, 398, 600] {
            for category: UIContentSizeCategory in [.large, .extraExtraExtraLarge, .accessibilityExtraExtraExtraLarge] {
                for rtl in [false, true] {
                    for (title, price, subtitle, recommended) in cases {
                        let traits = UITraitCollection(traitsFrom: [
                            UITraitCollection(preferredContentSizeCategory: category),
                            UITraitCollection(layoutDirection: rtl ? .rightToLeft : .leftToRight)
                        ])
                        traits.performAsCurrent {
                            let cell = PurchasePriceCell(style: .default, reuseIdentifier: nil)
                            if #available(iOS 17.0, *) {
                                cell.traitOverrides.preferredContentSizeCategory = category
                            }
                            cell.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
                            cell.contentView.semanticContentAttribute = cell.semanticContentAttribute
                            cell.traitCollectionDidChange(nil)
                            let product = StoreProduct(
                                productIdentifier: recommended ? PurchaseStoreID.lifetime198.rawValue : "other",
                                paywallTitle: title,
                                localizedPriceString: price
                            )
                            cell.update(model: product, isSelect: true, subtitle: subtitle)
                            let height = size(cell, width: width)
                            let visible = labels(in: cell).filter { isVisible($0) }
                            check(visible.count == 2 + (subtitle == nil ? 0 : 1) + (recommended ? 1 : 0), "Hidden details/badge must not occupy a line")
                            for label in visible {
                                let frame = label.convert(label.bounds, to: cell.contentView)
                                check(frame.width > 0 && frame.height > 0, "Label collapsed: \(title)")
                                check(frame.minX >= -0.5 && frame.maxX <= width + 0.5, "Text outside row: \(title)")
                                check(frame.minY >= -0.5 && frame.maxY <= height + 0.5, "Text outside fitted height: \(title)")
                                let requiredHeight = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height
                                check(label.bounds.height + 1 >= requiredHeight, "Text clipped: \(title), \(category.rawValue), \(width)")
                            }
                            for (index, label) in visible.enumerated() {
                                let frame = label.convert(label.bounds, to: cell.contentView)
                                for other in visible.dropFirst(index + 1) {
                                    let otherFrame = other.convert(other.bounds, to: cell.contentView)
                                    check(!frame.intersects(otherFrame), "Text overlaps: \(title), \(width), rtl=\(rtl)")
                                }
                            }
                            let priceLabel = visible.first { $0.text == price }!
                            let titleLabel = visible.first { $0.text == title }!
                            let priceFrame = priceLabel.convert(priceLabel.bounds, to: cell.contentView)
                            let titleFrame = titleLabel.convert(titleLabel.bounds, to: cell.contentView)
                            if !category.isAccessibilityCategory {
                                check(rtl ? priceFrame.maxX <= titleFrame.minX : priceFrame.minX >= titleFrame.maxX, "Price must stay in the trailing column: \(title), \(width), \(category.rawValue), rtl=\(rtl), title=\(titleFrame), price=\(priceFrame)")
                            }
                            if width >= 398 && category == .large && (title == "Monthly Premium" || title == "Annual Premium") {
                                check(height <= 76, "Regular-size rows should be compact")
                            }
                            check(cell.accessibilityLabel?.contains(price) == true, "Price must be spoken")
                            check(cell.accessibilityTraits.contains(.selected), "Selected plan must be spoken")

                            // Reusing the recommended/trial row for a normal monthly plan clears stale adornments.
                            cell.update(model: StoreProduct(productIdentifier: "monthly", paywallTitle: "Monthly", localizedPriceString: "$1"), isSelect: false)
                            _ = size(cell, width: width)
                            check(labels(in: cell).filter { isVisible($0) }.count == 2, "Reused row kept a badge or subtitle")
                            check(cell.accessibilityLabel == "Monthly, $1", "Reused row retained stale accessibility copy")
                            check(!cell.accessibilityTraits.contains(.selected), "Reused row retained selection")
                        }
                    }
                }
            }
        }
        print("PASS_PURCHASE_PRICE_CELL_LAYOUT assertions=\(assertions)")
        // Optional, isolated rendering of the real cells, not a screenshot of the user's app.
        // The runner only passes this argument when a destination is explicitly requested.
        if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--render" {
            renderChinesePlans(to: CommandLine.arguments[2], sizeCell: size)
        }
    }

    @MainActor private static func renderChinesePlans(
        to path: String,
        sizeCell: (PurchasePriceCell, CGFloat) -> CGFloat
    ) {
        usesChineseRecommendation = true
        defer { usesChineseRecommendation = false }
        let traits = UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: .dark),
            UITraitCollection(preferredContentSizeCategory: .large),
            UITraitCollection(layoutDirection: .leftToRight)
        ])
        traits.performAsCurrent {
            let canvas = UIView(frame: CGRect(x: 0, y: 0, width: 430, height: 500))
            canvas.overrideUserInterfaceStyle = .dark
            canvas.backgroundColor = .black
            let heading = UILabel(frame: CGRect(x: 24, y: 20, width: 382, height: 24))
            heading.text = "付费产品布局预览 · 简体中文"
            heading.font = .systemFont(ofSize: 15, weight: .medium)
            heading.textColor = .secondaryLabel
            canvas.addSubview(heading)
            let group = UIView(frame: CGRect(x: 20, y: 64, width: 390, height: 350))
            group.backgroundColor = .secondarySystemGroupedBackground
            group.layer.cornerRadius = 20
            group.clipsToBounds = true
            canvas.addSubview(group)
            let plans: [(String, String, String?, String)] = [
                ("月度高级版", "US$1.99", nil, "monthly"),
                ("年度高级版", "US$7.99", "US$0.67 / 月", "annual"),
                ("终身高级版", "US$19.99", nil, PurchaseStoreID.lifetime198.rawValue),
                ("家庭共享终身高级版", "US$39.99", nil, "family")
            ]
            var y: CGFloat = 0
            for (index, plan) in plans.enumerated() {
                let cell = PurchasePriceCell(style: .default, reuseIdentifier: nil)
                cell.overrideUserInterfaceStyle = .dark
                if #available(iOS 17.0, *) {
                    cell.traitOverrides.preferredContentSizeCategory = .large
                }
                cell.backgroundColor = .clear
                cell.selectionStyle = .none
                group.addSubview(cell)
                cell.update(
                    model: StoreProduct(productIdentifier: plan.3, paywallTitle: plan.0, localizedPriceString: plan.1),
                    isSelect: index == 1,
                    subtitle: plan.2
                )
                let rowHeight = ceil(sizeCell(cell, group.bounds.width))
                cell.frame = CGRect(x: 0, y: y, width: group.bounds.width, height: rowHeight)
                y += rowHeight
                if index < plans.count - 1 {
                    let separator = UIView(frame: CGRect(x: 16, y: y - 0.5, width: group.bounds.width - 32, height: 0.5))
                    separator.backgroundColor = .separator
                    group.addSubview(separator)
                }
            }
            group.frame.size.height = y
            let caption = UILabel(frame: CGRect(x: 24, y: group.frame.maxY + 16, width: 382, height: 0))
            caption.text = "真实 PurchasePriceCell 独立渲染。示例价格，未连接商店、未发起购买。"
            caption.font = .systemFont(ofSize: 12)
            caption.textColor = .secondaryLabel
            caption.numberOfLines = 0
            caption.frame.size.height = ceil(caption.sizeThatFits(CGSize(width: 382, height: CGFloat.greatestFiniteMagnitude)).height)
            canvas.addSubview(caption)
            canvas.frame.size.height = caption.frame.maxY + 24
            canvas.setNeedsLayout()
            canvas.layoutIfNeeded()
            // A headless probe has no UIWindow to propagate appearance into layers.
            // Resolve the real semantic colors before snapshotting those layers.
            func resolveAppearance(in view: UIView) {
                view.backgroundColor = view.backgroundColor?.resolvedColor(with: traits)
                view.tintColor = view.tintColor.resolvedColor(with: traits)
                if let label = view as? UILabel {
                    label.textColor = label.textColor.resolvedColor(with: traits)
                }
                view.subviews.forEach { resolveAppearance(in: $0) }
            }
            resolveAppearance(in: canvas)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 2
            format.opaque = true
            format.preferredRange = .standard
            let renderer = UIGraphicsImageRenderer(size: canvas.bounds.size, format: format)
            let image = renderer.image { context in
                canvas.layer.render(in: context.cgContext)
            }
            do {
                guard let data = image.pngData() else { preconditionFailure("Could not encode preview PNG") }
                try data.write(to: URL(fileURLWithPath: path))
                print("RENDERED_PURCHASE_PRICE_CELLS path=\(path) rowsHeight=\(y)")
            } catch {
                preconditionFailure("Could not write preview PNG: \(error)")
            }
        }
    }
}
