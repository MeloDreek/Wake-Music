//
//  ImportTableViewCell.swift
//  Mobie
//
//  Created by 张文 on 12/16/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

class ImportTableViewCell: UITableViewCell {
    private let serviceIcon = UIImageView()
    private let serviceTitle = UILabel()
    private let tagsView = ConnectionTagListView()
    private let textStack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .default
        self.accessoryType = .disclosureIndicator
        serviceIcon.contentMode = .scaleAspectFit
        serviceTitle.font = .preferredFont(forTextStyle: .body)
        serviceTitle.adjustsFontForContentSizeCategory = true
        serviceTitle.numberOfLines = 0
        tagsView.textColor = .secondaryLabel
        tagsView.tagBackgroundColor = .tertiarySystemFill
        tagsView.tag_cornerRadius = 5
        tagsView.paddingX = 7
        tagsView.paddingY = 3
        tagsView.marginX = 5
        tagsView.marginY = 5
        tagsView.isUserInteractionEnabled = false
        tagsView.accessibilityElementsHidden = true
        textStack.axis = .vertical
        textStack.spacing = 7
        textStack.addArrangedSubview(serviceTitle)
        textStack.addArrangedSubview(tagsView)
        for view in [serviceIcon, textStack] {
            view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(view)
        }
        NSLayoutConstraint.activate([
            serviceIcon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            serviceIcon.widthAnchor.constraint(equalToConstant: 30.ckValue()),
            serviceIcon.heightAnchor.constraint(equalTo: serviceIcon.widthAnchor),
            serviceIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textStack.leadingAnchor.constraint(equalTo: serviceIcon.trailingAnchor, constant: kaka_IsMacOS() ? 20 : 15),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),
            textStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 15),
            textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -15),
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 60)
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateItemType(itemType: ImportFileType) {
        serviceIcon.image = itemType.iconImage()
        serviceTitle.text = itemType.titleStr()
        serviceTitle.textColor = itemType.isAvailble() ? .label : .secondaryLabel
        tagsView.textFont = .preferredFont(forTextStyle: .caption1)
        tagsView.removeAllTags()
        let tags = itemType.connectionTags()
        tagsView.addTags(tags)
        tagsView.isHidden = tags.isEmpty
        accessibilityLabel = ([itemType.titleStr()] + tags).joined(separator: ", ")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            tagsView.textFont = .preferredFont(forTextStyle: .caption1)
        }
    }

    override func systemLayoutSizeFitting(_ targetSize: CGSize,
                                         withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
                                         verticalFittingPriority: UILayoutPriority) -> CGSize {
        // Tags wrap by width. Resolve the actual content width (including the disclosure
        // accessory) before measuring, otherwise a newly dequeued cell counts every tag as a row.
        bounds.size.width = targetSize.width
        setNeedsLayout()
        layoutIfNeeded()
        tagsView.invalidateIntrinsicContentSize()
        return super.systemLayoutSizeFitting(targetSize,
                                            withHorizontalFittingPriority: horizontalFittingPriority,
                                            verticalFittingPriority: verticalFittingPriority)
    }
    
}

/// A vertical stack supplies the width; calculate height from it before the tag view's layout pass.
private final class ConnectionTagListView: TagListView {
    override var intrinsicContentSize: CGSize {
        guard !tagViews.isEmpty else { return CGSize(width: UIView.noIntrinsicMetric, height: 0) }
        let availableWidth = max(1, bounds.width)
        var rows: CGFloat = 1
        var usedWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        for tag in tagViews {
            let size = tag.intrinsicContentSize
            let width = min(size.width, availableWidth)
            if usedWidth > 0 && usedWidth + marginX + width > availableWidth {
                rows += 1
                usedWidth = 0
            }
            usedWidth += (usedWidth > 0 ? marginX : 0) + width
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: UIView.noIntrinsicMetric, height: rows * rowHeight + (rows - 1) * marginY)
    }
}
