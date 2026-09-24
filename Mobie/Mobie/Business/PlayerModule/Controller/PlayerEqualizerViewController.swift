//
//  PlayerEqualizerViewController.swift
//  Mobie
//

import UIKit
import KakaFoundation
import KakaUIKit

/// A browsable audio rack. Every editing path checks entitlement before changing settings.
final class PlayerEqualizerViewController: SuperViewController {
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let powerSwitch = EQAccessSwitch()
    private let powerLamp = UIView()
    private let premiumButton = UIButton(type: .system)
    private let preampSlider = EQAccessSlider()
    private let bandScrollView = EQBandScrollView()
    private let presetGrid = EQPresetGrid()
    private let bandScrollHint = UIImageView(image: UIImage(systemName: "arrow.left.and.right"))
    private let preampValueLabel = EQStyle.label(size: 15, weight: .medium, monospaced: true)
    private var faders: [EQBandView] = []
    private var presetButtons: [PlayerEqualizerPreset: UIButton] = [:]

    override func preSetupSubViews() {
        super.preSetupSubViews()
        view.backgroundColor = EQStyle.background
        contentView.backgroundColor = EQStyle.background
        overrideUserInterfaceStyle = .dark
        title = "EQ.Title".localStr()
        navigationItem.largeTitleDisplayMode = .never
        configureNavigation()

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.delaysContentTouches = false
        scrollView.isDirectionalLockEnabled = true
        scrollView.indicatorStyle = .white
        scrollView.contentInsetAdjustmentBehavior = .never
        contentView.addSubview(scrollView)

        let canvas = UIView()
        canvas.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(canvas)

        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        canvas.addSubview(stack)
        let preferredWidth = stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        preferredWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            canvas.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            canvas.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            canvas.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            canvas.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            stack.topAnchor.constraint(equalTo: canvas.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: canvas.bottomAnchor, constant: -32),
            stack.centerXAnchor.constraint(equalTo: canvas.centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: canvas.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: canvas.trailingAnchor, constant: -16),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 880),
            preferredWidth,
        ])

        stack.addArrangedSubview(makeHeader())
        stack.addArrangedSubview(makePowerPanel())
        stack.addArrangedSubview(makePremiumButton())
        stack.addArrangedSubview(makePresetsPanel())
        stack.addArrangedSubview(makeBandsPanel())
        stack.addArrangedSubview(makePreampPanel())
        let guidance = EQStyle.label(size: 13, textStyle: .footnote)
        guidance.text = "EQ.ListeningGuide".localStr()
        guidance.textColor = EQStyle.secondary
        stack.addArrangedSubview(guidance)
        stack.addArrangedSubview(makeResetButton())
        refreshSettings()
    }

    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        NotificationCenter.default.addObserver(self, selector: #selector(refreshSettings), name: .playerEqualizerChanged, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshSettings()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        bandScrollView.flashScrollIndicators()
        presetGrid.scrollView.flashScrollIndicators()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        bandScrollHint.isHidden = bandScrollView.bounds.width >= CGFloat(faders.count) * 56
    }

    // This rack deliberately retains its dark finish without changing the surrounding app theme.
    override func appearanceChanged() {
        overrideUserInterfaceStyle = .dark
        setNeedsStatusBarAppearanceUpdate()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    private func configureNavigation() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = EQStyle.background
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [.foregroundColor: EQStyle.silver]
        let buttonAppearance = UIBarButtonItemAppearance(style: .plain)
        buttonAppearance.normal.titleTextAttributes = [.foregroundColor: EQStyle.silver]
        appearance.buttonAppearance = buttonAppearance
        appearance.doneButtonAppearance = buttonAppearance
        appearance.backButtonAppearance = buttonAppearance
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance
        let engine = UIBarButtonItem(image: UIImage(systemName: "cpu"), style: .plain,
                                     target: self, action: #selector(showPlayerEngine))
        engine.tintColor = EQStyle.silver
        engine.accessibilityLabel = SettingCellItemType.selectPlayer.titleStr()
        navigationItem.rightBarButtonItem = engine
        if isPresent(), navigationController?.viewControllers.first === self {
            let done = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(cancelButtonClick))
            done.tintColor = EQStyle.silver
            navigationItem.leftBarButtonItem = done
        }
    }

    @objc private func showPlayerEngine() {
        let engine = PlayerEngineViewController()
        if let navigationController {
            navigationController.pushViewController(engine, animated: true)
        } else {
            let navigation = KakaNavigationController(rootViewController: engine)
            navigation.modalPresentationStyle = kaka_IsiPad() ? .fullScreen : .automatic
            present(navigation, animated: true)
        }
    }

    private func makeHeader() -> UIView {
        let icon = UIImageView(image: UIImage(named: "player_equalizer") ?? UIImage(systemName: "slider.vertical.3"))
        icon.contentMode = .scaleAspectFit
        icon.tintColor = EQStyle.amber
        icon.isAccessibilityElement = false
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 76),
            icon.heightAnchor.constraint(equalToConstant: 76),
        ])
        let title = EQStyle.label(size: 27, weight: .bold, textStyle: .title1)
        title.text = "EQ.Title".localStr()
        title.accessibilityTraits.insert(.header)
        let note = EQStyle.label(size: 13, textStyle: .footnote)
        note.text = "EQ.EngineNote".localStr()
        note.textColor = EQStyle.secondary
        let text = EQStyle.column([title, note], spacing: 5)
        let row = UIStackView(arrangedSubviews: [icon, text])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 14
        return row
    }

    private func makePowerPanel() -> UIView {
        let panel = EQRackPanel()
        let title = EQStyle.label(size: 17, weight: .semibold)
        title.text = "EQ.Enabled".localStr()
        powerLamp.backgroundColor = EQStyle.amber
        powerLamp.layer.cornerRadius = 3
        powerLamp.layer.shadowColor = EQStyle.amber.cgColor
        powerLamp.layer.shadowRadius = 6
        powerLamp.layer.shadowOffset = .zero
        powerLamp.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            powerLamp.widthAnchor.constraint(equalToConstant: 6),
            powerLamp.heightAnchor.constraint(equalToConstant: 6),
        ])
        // Preserve the audio-rack's iOS controls in the Mac idiom as well.
        powerSwitch.preferredStyle = .sliding
        powerSwitch.onTintColor = EQStyle.amber
        powerSwitch.thumbTintColor = EQStyle.silver
        powerSwitch.accessibilityLabel = "EQ.Enabled".localStr()
        powerSwitch.authorize = { [weak self] in self?.authorizeEditing() ?? false }
        powerSwitch.addTarget(self, action: #selector(powerChanged), for: .valueChanged)
        let row = UIStackView(arrangedSubviews: [powerLamp, title, powerSwitch])
        row.alignment = .center
        row.spacing = 12
        title.setContentHuggingPriority(.defaultLow, for: .horizontal)
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        panel.install(row, inset: 20)
        return panel
    }

    private func makePremiumButton() -> UIView {
        premiumButton.preferredBehavioralStyle = .pad
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "crown.fill")
        configuration.imagePadding = 9
        configuration.baseForegroundColor = EQStyle.amber
        configuration.title = "EQ.Premium".localStr()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .systemFont(ofSize: 13, weight: .medium))
            return attributes
        }
        premiumButton.configuration = configuration
        premiumButton.titleLabel?.numberOfLines = 0
        premiumButton.titleLabel?.adjustsFontForContentSizeCategory = true
        premiumButton.titleLabel?.textAlignment = .center
        premiumButton.addTarget(self, action: #selector(showPremiumGuidance), for: .touchUpInside)
        premiumButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        return premiumButton
    }

    private func makePresetsPanel() -> UIView {
        let title = EQStyle.sectionTitle("EQ.Presets")
        let grid = presetGrid
        scrollView.panGestureRecognizer.require(toFail: grid.scrollView.panGestureRecognizer)
        for (row, presets) in PlayerEqualizerPreset.displayedPresetRows.enumerated() {
            for preset in presets {
                let button = UIButton(type: .system)
                button.preferredBehavioralStyle = .pad
                var configuration = UIButton.Configuration.filled()
                configuration.title = preset.title
                configuration.titleLineBreakMode = .byWordWrapping
                configuration.baseBackgroundColor = EQStyle.recess
                configuration.baseForegroundColor = EQStyle.secondary
                configuration.cornerStyle = .fixed
                configuration.background.cornerRadius = 9
                configuration.background.strokeWidth = 1
                configuration.background.strokeColor = EQStyle.edge
                configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
                configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                    var attributes = attributes
                    attributes.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: .systemFont(ofSize: 14, weight: .semibold))
                    return attributes
                }
                button.configuration = configuration
                button.titleLabel?.adjustsFontForContentSizeCategory = true
                button.titleLabel?.numberOfLines = 0
                button.titleLabel?.textAlignment = .center
                button.addAction(UIAction { [weak self] _ in
                    self?.edit { settings in settings.selectPreset(preset) }
                }, for: .touchUpInside)
                presetButtons[preset] = button
                grid.addButton(button, row: row)
            }
        }
        let note = EQStyle.label(size: 12, textStyle: .footnote)
        note.text = "EQ.PresetsGuide".localStr()
        note.textColor = EQStyle.secondary
        return EQStyle.column([title, grid, note], spacing: 10)
    }

    private func makeBandsPanel() -> UIView {
        let panel = EQRackPanel()
        let title = EQStyle.sectionTitle("EQ.Bands")
        let scale = EQStyle.label(size: 11, weight: .medium, textStyle: .caption1, monospaced: true)
        scale.text = "±12 dB"
        scale.textColor = EQStyle.secondary
        scale.setContentCompressionResistancePriority(.required, for: .horizontal)
        bandScrollHint.tintColor = EQStyle.secondary
        bandScrollHint.contentMode = .scaleAspectFit
        bandScrollHint.isAccessibilityElement = false
        bandScrollHint.translatesAutoresizingMaskIntoConstraints = false
        bandScrollHint.widthAnchor.constraint(equalToConstant: 15).isActive = true
        let header = UIStackView(arrangedSubviews: [title, scale, bandScrollHint])
        header.axis = .horizontal
        header.alignment = .firstBaseline
        header.spacing = 8
        title.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let scroll = bandScrollView
        scroll.indicatorStyle = .white
        scroll.showsHorizontalScrollIndicator = true
        scroll.alwaysBounceHorizontal = false
        scroll.isDirectionalLockEnabled = true
        scroll.delaysContentTouches = false
        scroll.canCancelContentTouches = true
        scroll.contentInsetAdjustmentBehavior = .never
        // Audio frequencies stay low-to-high regardless of the interface's reading direction.
        scroll.semanticContentAttribute = .forceLeftToRight
        // Let a horizontal band swipe finish its directional decision before the page scrolls.
        scrollView.panGestureRecognizer.require(toFail: scroll.panGestureRecognizer)
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 2
        row.semanticContentAttribute = .forceLeftToRight
        row.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(row)
        for (index, frequency) in PlayerEqualizerSettings.frequencies.enumerated() {
            let band = EQBandView(frequency: frequency)
            // A vertical fader drag wins over both scroll views. Its recognizer explicitly
            // rejects horizontal motion, so swiping on a knob can still browse the bands.
            scroll.panGestureRecognizer.require(toFail: band.fader.adjustmentGesture)
            scrollView.panGestureRecognizer.require(toFail: band.fader.adjustmentGesture)
            band.fader.authorize = { [weak self] in self?.authorizeEditing() ?? false }
            band.fader.addAction(UIAction { [weak self, weak band] _ in
                guard let band else { return }
                self?.edit { settings in
                    guard settings.gains.indices.contains(index) else { return }
                    settings.gains[index] = band.fader.value
                    settings.saveCustomCurve()
                }
            }, for: .valueChanged)
            faders.append(band)
            row.addArrangedSubview(band)
        }
        let intrinsicWidth = row.widthAnchor.constraint(greaterThanOrEqualToConstant: CGFloat(faders.count) * 56)
        let viewportWidth = row.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        viewportWidth.priority = .defaultLow
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            row.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            row.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -12),
            row.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor, constant: -12),
            intrinsicWidth, viewportWidth,
        ])
        let contents = EQStyle.column([header, scroll], spacing: 18)
        panel.install(contents, inset: 20)
        return panel
    }

    private func makePreampPanel() -> UIView {
        let panel = EQRackPanel()
        let title = EQStyle.sectionTitle("EQ.Preamp")
        preampValueLabel.textColor = EQStyle.amber
        preampValueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        let header = UIStackView(arrangedSubviews: [title, preampValueLabel])
        header.axis = .horizontal
        header.alignment = .firstBaseline
        header.spacing = 12
        title.setContentHuggingPriority(.defaultLow, for: .horizontal)

        preampSlider.minimumValue = -12
        preampSlider.maximumValue = 0
        preampSlider.preferredBehavioralStyle = .pad
        // Never customize an AppKit-backed slider: unsupported track/thumbnail
        // setters can throw. The explicitly requested iOS control supports them.
        if preampSlider.behavioralStyle == .pad {
            preampSlider.minimumTrackTintColor = EQStyle.amber.withAlphaComponent(0.8)
            preampSlider.maximumTrackTintColor = EQStyle.recess
            preampSlider.setThumbImage(EQStyle.horizontalThumb(), for: .normal)
            preampSlider.setThumbImage(EQStyle.horizontalThumb(), for: .highlighted)
        }
        preampSlider.accessibilityLabel = "EQ.Preamp".localStr()
        preampSlider.authorize = { [weak self] in self?.authorizeEditing() ?? false }
        preampSlider.addTarget(self, action: #selector(preampChanged), for: .valueChanged)
        preampSlider.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true

        let low = EQStyle.label(size: 11, textStyle: .caption1, monospaced: true)
        low.text = "−12 dB"
        low.textColor = EQStyle.secondary
        let high = EQStyle.label(size: 11, textStyle: .caption1, monospaced: true)
        high.text = "0 dB"
        high.textColor = EQStyle.secondary
        high.textAlignment = .right
        let ends = UIStackView(arrangedSubviews: [low, high])
        ends.axis = .horizontal
        ends.distribution = .fillEqually
        ends.isAccessibilityElement = false
        ends.accessibilityElementsHidden = true

        let note = EQStyle.label(size: 12, textStyle: .footnote)
        note.text = "EQ.Headroom".localStr()
        note.textColor = EQStyle.secondary
        let contents = EQStyle.column([header, preampSlider, ends, note], spacing: 7)
        contents.setCustomSpacing(13, after: ends)
        panel.install(contents, inset: 20)
        return panel
    }

    private func makeResetButton() -> UIView {
        let button = UIButton(type: .system)
        button.preferredBehavioralStyle = .pad
        var configuration = UIButton.Configuration.plain()
        configuration.title = "EQ.Reset".localStr()
        configuration.image = UIImage(systemName: "arrow.counterclockwise")
        configuration.imagePadding = 7
        configuration.baseForegroundColor = EQStyle.secondary
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
        button.configuration = configuration
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.numberOfLines = 0
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.addAction(UIAction { [weak self] _ in
            self?.edit { settings in
                settings.selectPreset(.flat)
                settings.preamp = 0
            }
        }, for: .touchUpInside)
        return button
    }

    @objc private func powerChanged() {
        edit { $0.isEnabled = powerSwitch.isOn }
    }

    @objc private func preampChanged() {
        edit {
            $0.preamp = (preampSlider.value * 2).rounded() / 2
            $0.saveCustomCurve()
        }
    }

    private func authorizeEditing() -> Bool {
        guard PlayerEqualizerStore.hasAccess else {
            refreshSettings()
            showPremiumGuidance()
            return false
        }
        return true
    }

    @objc private func showPremiumGuidance() {
        guard !PlayerEqualizerStore.hasAccess, presentedViewController == nil else { return }
        showTwoAlert(message: "EQ.PremiumPrompt".localStr(), confirm: "Unlock Premium".localStr()) { [weak self] in
            guard let self, !PlayerEqualizerStore.hasAccess else { return }
            self.vipCenterClick()
        }
    }

    private func edit(_ mutation: (inout PlayerEqualizerSettings) -> Void) {
        guard authorizeEditing() else { return }
        var settings = PlayerEqualizerStore.shared.settings
        mutation(&settings)
        if !PlayerEqualizerStore.shared.update(settings) {
            _ = authorizeEditing()
        }
        refreshSettings()
    }

    @objc private func refreshSettings() {
        let settings = PlayerEqualizerStore.shared.settings
        let hasAccess = PlayerEqualizerStore.hasAccess
        let isActive = hasAccess && settings.isEnabled
        powerSwitch.setOn(isActive, animated: false)
        powerLamp.backgroundColor = isActive ? EQStyle.amber : EQStyle.secondary.withAlphaComponent(0.35)
        powerLamp.layer.shadowOpacity = isActive ? 0.75 : 0
        premiumButton.isHidden = hasAccess
        powerSwitch.accessibilityHint = hasAccess ? nil : "EQ.Premium".localStr()
        for (index, band) in faders.enumerated() where settings.gains.indices.contains(index) {
            band.setValue(settings.gains[index], active: isActive)
            band.fader.accessibilityHint = hasAccess ? nil : "EQ.Premium".localStr()
        }
        for (preset, button) in presetButtons {
            let selected = settings.preset == preset
            button.configuration?.baseBackgroundColor = selected ? EQStyle.amber.withAlphaComponent(0.14) : EQStyle.recess
            button.configuration?.baseForegroundColor = selected ? EQStyle.amber : EQStyle.secondary
            button.configuration?.background.strokeColor = selected ? EQStyle.amber.withAlphaComponent(0.65) : EQStyle.edge
            button.accessibilityTraits = selected ? [.button, .selected] : [.button]
            button.accessibilityHint = hasAccess ? nil : "EQ.Premium".localStr()
        }
        preampSlider.setValue(settings.preamp, animated: false)
        preampValueLabel.text = EQStyle.decibels(settings.preamp)
        preampSlider.accessibilityValue = EQStyle.decibels(settings.preamp)
        preampSlider.accessibilityHint = hasAccess ? nil : "EQ.Premium".localStr()
    }
}

/// Three rows of five inside a horizontal viewport, sized to the longest title.
private final class EQPresetGrid: UIView {
    let scrollView: UIScrollView = HorizontalScrollView()
    private var buttonRows: [[UIButton]] = Array(repeating: [], count: 3)
    private var measuredWidth: CGFloat = 0
    private var previousDirection: UIUserInterfaceLayoutDirection?

    override init(frame: CGRect) {
        super.init(frame: frame)
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsVerticalScrollIndicator = false
        scrollView.indicatorStyle = .white
        scrollView.isDirectionalLockEnabled = true
        addSubview(scrollView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func addButton(_ button: UIButton, row: Int) {
        precondition(buttonRows.indices.contains(row))
        buttonRows[row].append(button)
        scrollView.addSubview(button)
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: arrange(width: max(1, bounds.width), apply: false))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if measuredWidth != bounds.width {
            measuredWidth = bounds.width
            invalidateIntrinsicContentSize()
        }
        _ = arrange(width: max(1, bounds.width), apply: true)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    private func arrange(width: CGFloat, apply: Bool) -> CGFloat {
        let buttons = buttonRows.flatMap { $0 }
        guard !buttons.isEmpty else { return 0 }
        let rows = buttonRows.count
        let columns = buttonRows.map(\.count).max() ?? 0
        let spacing: CGFloat = 8
        // UIButton includes the title's current font and the configured horizontal
        // padding (16 pt per side). Do not stretch short titles to fill the viewport.
        let naturalWidth = buttons.reduce(CGFloat(44)) { result, button in
            max(result, ceil(button.sizeThatFits(UIView.layoutFittingExpandedSize).width))
        }
        // Allow wrapping only when a large accessibility title cannot fit on screen.
        let columnWidth = min(max(44, width), naturalWidth)
        let rowHeight = buttons.reduce(CGFloat(44)) { height, button in
            max(height, ceil(button.sizeThatFits(CGSize(width: columnWidth, height: .greatestFiniteMagnitude)).height))
        }
        let contentWidth = max(width, CGFloat(columns) * (columnWidth + spacing) - spacing)
        let height = CGFloat(rows) * (rowHeight + spacing) - spacing + 8
        if apply {
            let direction = effectiveUserInterfaceLayoutDirection
            let rtl = direction == .rightToLeft
            let oldMaximum = max(0, scrollView.contentSize.width - scrollView.bounds.width)
            let leadingOffset = previousDirection == .rightToLeft
                ? oldMaximum - scrollView.contentOffset.x : scrollView.contentOffset.x
            scrollView.frame = bounds
            scrollView.contentSize = CGSize(width: contentWidth, height: height)
            for (row, buttons) in buttonRows.enumerated() {
                for (column, button) in buttons.enumerated() {
                    let x = CGFloat(column) * (columnWidth + spacing)
                    let y = CGFloat(row) * (rowHeight + spacing)
                    button.frame = CGRect(x: rtl ? contentWidth - x - columnWidth : x,
                                          y: y, width: columnWidth, height: rowHeight)
                }
            }
            let maximum = max(0, contentWidth - width)
            let offset = min(maximum, max(0, leadingOffset))
            scrollView.contentOffset = CGPoint(x: rtl ? maximum - offset : offset, y: 0)
            previousDirection = direction
        }
        return height
    }

    private final class HorizontalScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool { true }

        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer === panGestureRecognizer {
                let velocity = panGestureRecognizer.velocity(in: self)
                guard contentSize.width > bounds.width, abs(velocity.x) > abs(velocity.y) else { return false }
            }
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
    }
}

// MARK: - Rack finish

private enum EQStyle {
    static let background = UIColor(red: 0.065, green: 0.071, blue: 0.079, alpha: 1)
    static let recess = UIColor(red: 0.075, green: 0.082, blue: 0.09, alpha: 1)
    static let edge = UIColor(white: 0.26, alpha: 1)
    static let silver = UIColor(red: 0.9, green: 0.91, blue: 0.92, alpha: 1)
    static let secondary = UIColor(red: 0.65, green: 0.68, blue: 0.71, alpha: 1)
    static let amber = UIColor(red: 1, green: 0.72, blue: 0.33, alpha: 1)

    static func label(size: CGFloat, weight: UIFont.Weight = .regular, textStyle: UIFont.TextStyle = .body, monospaced: Bool = false) -> UILabel {
        let label = UILabel()
        let font = monospaced ? UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight) : UIFont.systemFont(ofSize: size, weight: weight)
        label.font = UIFontMetrics(forTextStyle: textStyle).scaledFont(for: font)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textColor = silver
        return label
    }

    static func sectionTitle(_ key: String) -> UILabel {
        let title = label(size: 14, weight: .semibold, textStyle: .subheadline)
        title.text = key.localStr()
        title.accessibilityTraits.insert(.header)
        return title
    }

    static func column(_ views: [UIView], spacing: CGFloat) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.spacing = spacing
        return stack
    }

    static func decibels(_ value: Float) -> String {
        if abs(value) < 0.05 { return "0 dB" }
        let format = value.rounded() == value ? "%+.0f dB" : "%+.1f dB"
        return String(format: format, locale: Locale.current, value)
    }

    static func horizontalThumb() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 34, height: 34)).image { renderer in
            let context = renderer.cgContext
            drawKnob(in: CGRect(x: 3, y: 3, width: 28, height: 28), context: context, vertical: false)
        }
    }

    static func drawKnob(in rect: CGRect, context: CGContext, vertical: Bool) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 5)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 3), blur: 4, color: UIColor.black.withAlphaComponent(0.8).cgColor)
        UIColor(white: 0.35, alpha: 1).setFill()
        path.fill()
        context.restoreGState()
        context.saveGState()
        path.addClip()
        let colors = [UIColor(white: 0.88, alpha: 1).cgColor,
                      UIColor(white: 0.56, alpha: 1).cgColor,
                      UIColor(white: 0.76, alpha: 1).cgColor,
                      UIColor(white: 0.39, alpha: 1).cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.23, 0.55, 1]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.minY), end: CGPoint(x: rect.midX, y: rect.maxY), options: [])
        }
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.22).cgColor)
        context.setLineWidth(0.5)
        for inset: CGFloat in [-7, -4, 4, 7] {
            if vertical {
                context.move(to: CGPoint(x: rect.minX + 6, y: rect.midY + inset))
                context.addLine(to: CGPoint(x: rect.maxX - 6, y: rect.midY + inset))
            } else {
                context.move(to: CGPoint(x: rect.midX + inset, y: rect.minY + 6))
                context.addLine(to: CGPoint(x: rect.midX + inset, y: rect.maxY - 6))
            }
        }
        context.strokePath()
        context.restoreGState()
        UIColor.white.withAlphaComponent(0.3).setStroke()
        path.lineWidth = 0.7
        path.stroke()
        let indicator: CGRect = vertical
            ? CGRect(x: rect.minX + 5, y: rect.midY - 1, width: rect.width - 10, height: 2)
            : CGRect(x: rect.midX - 1, y: rect.minY + 5, width: 2, height: rect.height - 10)
        UIColor(white: 0.1, alpha: 1).setFill()
        UIBezierPath(roundedRect: indicator.insetBy(dx: -0.8, dy: -0.8), cornerRadius: 1).fill()
        amber.setFill()
        UIBezierPath(roundedRect: indicator, cornerRadius: 1).fill()
    }
}

private final class EQRackPanel: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 14
        layer.borderWidth = 0.75
        layer.borderColor = EQStyle.edge.cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.28
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8
        backgroundColor = .clear
        isOpaque = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func install(_ content: UIView, inset: CGFloat) {
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            content.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 14).cgPath
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        UIBezierPath(roundedRect: bounds, cornerRadius: 14).addClip()
        let colors = [UIColor(white: 0.18, alpha: 1).cgColor, UIColor(white: 0.115, alpha: 1).cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: bounds.width * 0.3, y: bounds.height), options: [])
        }
        context.restoreGState()
        // Small countersunk fasteners give the rack a physical edge without distracting from labels.
        for x in [CGFloat(8), bounds.width - 8] {
            for y in [CGFloat(8), bounds.height - 8] {
                let screw = CGRect(x: x - 2.5, y: y - 2.5, width: 5, height: 5)
                context.setFillColor(UIColor(white: 0.09, alpha: 1).cgColor)
                context.fillEllipse(in: screw)
                context.setStrokeColor(UIColor(white: 0.35, alpha: 1).cgColor)
                context.setLineWidth(0.6)
                context.strokeEllipse(in: screw)
                context.move(to: CGPoint(x: x - 1.2, y: y + 1.2))
                context.addLine(to: CGPoint(x: x + 1.2, y: y - 1.2))
                context.strokePath()
            }
        }
    }
}

// MARK: - Accessible controls

private final class EQBandScrollView: UIScrollView {
    override func touchesShouldCancel(in view: UIView) -> Bool {
        // UIControl normally keeps its touches. Faders use their own directional pan,
        // so ordinary control tracking must not block a horizontal scroll takeover.
        if view is EQVerticalFader { return true }
        return super.touchesShouldCancel(in: view)
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === panGestureRecognizer {
            let translation = panGestureRecognizer.translation(in: self)
            guard abs(translation.x) > abs(translation.y) else { return false }
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
}

private final class EQBandView: UIStackView {
    let fader = EQVerticalFader()
    private let valueLabel = EQStyle.label(size: 11, weight: .medium, textStyle: .caption1, monospaced: true)

    init(frequency: Float) {
        super.init(frame: .zero)
        axis = .vertical
        alignment = .fill
        spacing = 9
        valueLabel.textAlignment = .center
        valueLabel.isAccessibilityElement = false
        let frequencyLabel = EQStyle.label(size: 12, weight: .semibold, textStyle: .caption1, monospaced: true)
        frequencyLabel.text = frequency >= 1000 ? String(format: "%.0fk", frequency / 1000) : String(format: "%.0f", frequency)
        frequencyLabel.textAlignment = .center
        frequencyLabel.isAccessibilityElement = false
        fader.accessibilityLabel = String(format: "%.0f Hz", frequency)
        fader.heightAnchor.constraint(equalToConstant: 196).isActive = true
        addArrangedSubview(valueLabel)
        addArrangedSubview(fader)
        addArrangedSubview(frequencyLabel)
        // Each control remains reachable by touch, even when the frequency strip scrolls.
        widthAnchor.constraint(greaterThanOrEqualToConstant: 54).isActive = true
        fader.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.valueLabel.text = EQStyle.decibels(self.fader.value)
        }, for: .valueChanged)
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setValue(_ value: Float, active: Bool) {
        fader.value = value
        fader.isActive = active
        valueLabel.text = EQStyle.decibels(value)
        valueLabel.textColor = active ? EQStyle.amber : EQStyle.secondary
    }
}

private final class EQVerticalFader: UIControl, UIGestureRecognizerDelegate {
    var authorize: (() -> Bool)?
    let adjustmentGesture = UIPanGestureRecognizer()
    var value: Float = 0 {
        didSet {
            accessibilityValue = EQStyle.decibels(value)
            setNeedsDisplay()
        }
    }
    var isActive = false { didSet { setNeedsDisplay() } }
    private var trackTop: CGFloat { 16 }
    private var trackBottom: CGFloat { bounds.height - 16 }
    private var panAuthorized = false
    private var panOrigin: CGPoint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isAccessibilityElement = true
        accessibilityTraits = .adjustable
        accessibilityValue = EQStyle.decibels(value)
        adjustmentGesture.addTarget(self, action: #selector(adjustmentPanned(_:)))
        adjustmentGesture.maximumNumberOfTouches = 1
        adjustmentGesture.delegate = self
        addGestureRecognizer(adjustmentGesture)
        let tap = UITapGestureRecognizer(target: self, action: #selector(trackTapped(_:)))
        tap.require(toFail: adjustmentGesture)
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        // Gesture recognizers own taps and drags; UIControl tracking must never trap a
        // horizontal touch sequence before the enclosing scroll view can receive it.
        return false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer === adjustmentGesture {
            panOrigin = touch.location(in: self)
        }
        return true
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === adjustmentGesture {
            let translation: CGPoint
            if let panOrigin {
                let current = adjustmentGesture.location(in: self)
                translation = CGPoint(x: current.x - panOrigin.x, y: current.y - panOrigin.y)
            } else {
                translation = adjustmentGesture.translation(in: self)
            }
            // Direction is resolved before authorization: browsing sideways never edits
            // a band or opens the paywall, even if the swipe starts on its metal knob.
            // Instantaneous velocity may be zero at recognition; displacement and a
            // strict comparison also prevent a zero/zero tie from starting an edit.
            return abs(translation.y) > abs(translation.x) && abs(translation.y) >= 4
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    @objc private func adjustmentPanned(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            panAuthorized = authorize?() ?? false
            guard panAuthorized else { return }
            isHighlighted = true
            updateValue(at: gesture.location(in: self))
        case .changed:
            guard panAuthorized else { return }
            // Revocation during a drag must stop updates as well.
            guard authorize?() ?? false else {
                panAuthorized = false
                isHighlighted = false
                return
            }
            updateValue(at: gesture.location(in: self))
        case .ended, .cancelled, .failed:
            panAuthorized = false
            isHighlighted = false
        default:
            break
        }
    }

    @objc private func trackTapped(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended, authorize?() ?? false else { return }
        updateValue(at: gesture.location(in: self))
    }

    override func accessibilityIncrement() { adjust(by: 0.5) }
    override func accessibilityDecrement() { adjust(by: -0.5) }

    private func adjust(by amount: Float) {
        guard authorize?() ?? false else { return }
        setInteractiveValue(value + amount)
    }

    private func updateValue(at point: CGPoint) {
        let fraction = (trackBottom - point.y) / max(1, trackBottom - trackTop)
        setInteractiveValue(Float(fraction) * 24 - 12)
    }

    private func setInteractiveValue(_ newValue: Float) {
        let newValue = (min(12, max(-12, newValue)) * 2).rounded() / 2
        guard value != newValue else { return }
        value = newValue
        sendActions(for: .valueChanged)
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let center = bounds.midX
        let travel = trackBottom - trackTop
        context.setLineWidth(1)
        for index in 0...8 {
            let y = trackTop + travel * CGFloat(index) / 8
            let isZero = index == 4
            context.setStrokeColor((isZero ? EQStyle.secondary : UIColor(white: 0.3, alpha: 1)).cgColor)
            let edge: CGFloat = isZero ? 5 : 9
            context.move(to: CGPoint(x: edge, y: y))
            context.addLine(to: CGPoint(x: center - 8, y: y))
            context.move(to: CGPoint(x: center + 8, y: y))
            context.addLine(to: CGPoint(x: bounds.width - edge, y: y))
            context.strokePath()
        }
        let channel = CGRect(x: center - 3, y: trackTop - 2, width: 6, height: travel + 4)
        UIColor.black.withAlphaComponent(0.8).setFill()
        UIBezierPath(roundedRect: channel, cornerRadius: 3).fill()
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.07).cgColor)
        context.move(to: CGPoint(x: center + 4, y: trackTop))
        context.addLine(to: CGPoint(x: center + 4, y: trackBottom))
        context.strokePath()
        let y = trackBottom - CGFloat((value + 12) / 24) * travel
        let zero = trackTop + travel / 2
        if abs(value) > 0.01 {
            context.setStrokeColor(EQStyle.amber.withAlphaComponent(isActive ? 0.8 : 0.25).cgColor)
            context.setLineWidth(2)
            context.move(to: CGPoint(x: center, y: zero))
            context.addLine(to: CGPoint(x: center, y: y))
            context.strokePath()
        }
        EQStyle.drawKnob(in: CGRect(x: center - 17, y: y - 13, width: 34, height: 26), context: context, vertical: true)
    }
}

/// UISlider keeps native pointer, keyboard, and VoiceOver behavior with an entitlement check.
private final class EQAccessSlider: UISlider {
    var authorize: (() -> Bool)?

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        guard authorize?() ?? false else { return false }
        return super.beginTracking(touch, with: event)
    }

    override func accessibilityIncrement() {
        guard authorize?() ?? false else { return }
        super.accessibilityIncrement()
    }

    override func accessibilityDecrement() {
        guard authorize?() ?? false else { return }
        super.accessibilityDecrement()
    }
}

private final class EQAccessSwitch: UISwitch {
    var authorize: (() -> Bool)?

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        guard authorize?() ?? false else { return false }
        return super.beginTracking(touch, with: event)
    }

    override func accessibilityActivate() -> Bool {
        guard authorize?() ?? false else { return true }
        return super.accessibilityActivate()
    }
}
