import AppKit

/// The dropdown's faceplate: one row width, two insets, one label column, and
/// the two type voices every register in the menu wears. The rule that makes
/// the whole menu read as an instrument: **the measurement face is for numbers
/// only, the system face is for words only, and the tier accent is the only
/// color in the menu.** Nothing here draws a background, a border or a card —
/// the menu's own material is the surface.
@MainActor
enum MenuMetrics {
    static let rowWidth: CGFloat = 288
    static let insetLeading: CGFloat = 12
    static let insetTrailing: CGFloat = 12
    static let labelColumnWidth: CGFloat = 104
    static let labelValueGap: CGFloat = 8

    static let rowHeight: CGFloat = 24
    static let sectionRowHeight: CGFloat = 26
    static let scaleRowHeight: CGFloat = 30
    static let messageRowHeight: CGFloat = 22

    /// Words: labels, section heads, plain lines, and state words.
    static func labelFont() -> NSFont { NSFont.systemFont(ofSize: 11) }
    static func noteFont() -> NSFont { NSFont.systemFont(ofSize: 11) }
    static func sectionFont() -> NSFont { NSFont.systemFont(ofSize: 10, weight: .medium) }
    static func actionFont() -> NSFont { NSFont.menuFont(ofSize: 13) }
    /// Numbers: every measured value, the ruler's tick labels, and the status
    /// item itself. One measurement voice across all three.
    static func measurementFont() -> NSFont { NSFont.monospacedSystemFont(ofSize: 11, weight: .medium) }
    static func tickFont() -> NSFont { NSFont.monospacedSystemFont(ofSize: 8.5, weight: .regular) }
    static func titleFont() -> NSFont { NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular) }

    static let sectionTracking: CGFloat = 0.6
}

// MARK: - Colors from a signal

extension MenuSignal {
    /// The accent a state word wears, or `nil` when it stays neutral.
    @MainActor
    func accentColor() -> NSColor? {
        switch self {
        case .neutral: return nil
        case .thermal(let tier): return StatusStyle.color(for: tier)
        case .health(let condition): return StatusStyle.color(for: condition)
        }
    }
}

// MARK: - Row views

@MainActor
enum MenuItemViews {
    /// The dropdown's only text control, configured for a row that must never
    /// become editable, selectable, or click-targeted. Frame-positioned: the
    /// rows place their own fields, so the flag that hands the frame to Auto
    /// Layout stays off (it would zero the frame wherever a window is absent).
    static func makeTextField() -> NSTextField {
        let field = NSTextField()
        field.isEditable = false
        field.isBezeled = false
        field.isBordered = false
        field.drawsBackground = false
        field.isSelectable = false
        field.allowsEditingTextAttributes = false
        field.usesSingleLineMode = true
        field.lineBreakMode = .byTruncatingTail
        field.maximumNumberOfLines = 1
        return field
    }

    static func makeLabel(_ string: String, font: NSFont, color: NSColor, tracking: CGFloat = 0) -> NSTextField {
        let field = makeTextField()
        var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        if tracking != 0 { attributes[.kern] = tracking }
        field.attributedStringValue = NSAttributedString(string: string, attributes: attributes)
        return field
    }

    /// The value column: measurement in the measurement face, then the state
    /// word in the human face when the register carries one.
    static func makeValueField(_ value: MenuValue) -> NSTextField {
        let field = makeTextField()
        field.alignment = .right
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.attributedStringValue = valueAttributedString(value)
        return field
    }

    static func valueAttributedString(_ value: MenuValue) -> NSAttributedString {
        let baseColor: NSColor = value.isUnavailable ? .secondaryLabelColor : .labelColor
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        let composed = NSMutableAttributedString(string: value.measurement, attributes: [
            .font: MenuMetrics.measurementFont(),
            .foregroundColor: baseColor,
            .paragraphStyle: paragraph,
        ])
        if let note = value.note {
            let noteColor = value.isUnavailable
                ? NSColor.secondaryLabelColor
                : (value.signal.accentColor() ?? NSColor.secondaryLabelColor)
            composed.append(NSAttributedString(string: " · \(note)", attributes: [
                .font: MenuMetrics.noteFont(),
                .foregroundColor: noteColor,
                .paragraphStyle: paragraph,
            ]))
        }
        return composed
    }
}

/// A labelled register: label in the left column, value pinned to the right
/// margin so every reading in the menu lines up on one edge. Positions its
/// fields with explicit frames — AppKit's constraint engine needs a window to
/// solve, and a menu row must be correct before it has one.
@MainActor
final class MenuMetricRowView: NSView {
    private let labelField: NSTextField
    private let valueField: NSTextField

    init(label: String, value: MenuValue) {
        labelField = MenuItemViews.makeLabel(
            label, font: MenuMetrics.labelFont(), color: .secondaryLabelColor
        )
        valueField = MenuItemViews.makeValueField(value)
        super.init(frame: NSRect(x: 0, y: 0, width: MenuMetrics.rowWidth, height: MenuMetrics.rowHeight))
        wantsLayer = true
        addSubview(labelField)
        addSubview(valueField)
        layoutFields()

        setAccessibilityLabel("\(label), \(value.measurement)\(value.note.map { ", \($0)" } ?? "")")
        setAccessibilityRole(.staticText)
    }

    override func layout() {
        super.layout()
        layoutFields()
    }

    private func layoutFields() {
        let width = bounds.width
        labelField.frame = NSRect(
            x: MenuMetrics.insetLeading,
            y: 0,
            width: MenuMetrics.labelColumnWidth,
            height: MenuMetrics.rowHeight
        )
        labelField.autoresizingMask = []
        valueField.frame = NSRect(
            x: MenuMetrics.insetLeading + MenuMetrics.labelColumnWidth + MenuMetrics.labelValueGap,
            y: 0,
            width: max(
                0,
                width - MenuMetrics.insetTrailing
                    - MenuMetrics.insetLeading - MenuMetrics.labelColumnWidth
                    - MenuMetrics.labelValueGap
            ),
            height: MenuMetrics.rowHeight
        )
        valueField.autoresizingMask = [.width]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

/// A section head: uppercase, tracked, quiet, with more air above it than
/// below so the group it names opens rather than floats.
@MainActor
final class MenuSectionRowView: NSView {
    private let head: NSTextField

    init(title: String) {
        head = MenuItemViews.makeLabel(
            title.uppercased(),
            font: MenuMetrics.sectionFont(),
            color: .secondaryLabelColor,
            tracking: MenuMetrics.sectionTracking
        )
        super.init(frame: NSRect(
            x: 0, y: 0, width: MenuMetrics.rowWidth, height: MenuMetrics.sectionRowHeight
        ))
        wantsLayer = true
        addSubview(head)
        layoutHead()

        setAccessibilityLabel(title)
        setAccessibilityRole(.staticText)
    }

    override func layout() {
        super.layout()
        layoutHead()
    }

    private func layoutHead() {
        // 8pt above the head, 5pt below: the head sits against the group it
        // names rather than floating between groups.
        head.frame = NSRect(
            x: MenuMetrics.insetLeading,
            y: 3,
            width: max(0, bounds.width - 2 * MenuMetrics.insetLeading),
            height: MenuMetrics.sectionRowHeight - 8
        )
        head.autoresizingMask = [.width]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

/// The dropdown's signature: a hairline ruler spanning the menu's inner width,
/// the live tier's band lit, the two threshold ticks labelled, and a needle
/// that slides to the reading as the menu opens.
@MainActor
final class ThermalScaleRowView: NSView {
    /// The reading marker: taller than the track, in the label color so it
    /// reads against both the lit band and the neutral track — a tier-colored
    /// needle would vanish inside its own band. Paints itself rather than
    /// filling a layer, so it appears in every draw path.
    private final class Needle: NSView {
        override func draw(_ dirtyRect: NSRect) {
            NSColor.labelColor.setFill()
            NSBezierPath(
                roundedRect: bounds,
                xRadius: bounds.width / 2,
                yRadius: bounds.width / 2
            ).fill()
        }
    }

    private let reading: ThermalReading
    private let needle = Needle()
    private var entrancePlayed = false

    /// Ruler layout, in points from the row's bottom edge.
    private let trackCenterY: CGFloat = 20
    private let trackThickness: CGFloat = 2.5
    private let needleHeight: CGFloat = 11
    private let needleWidth: CGFloat = 2.5
    private let tickLength: CGFloat = 6
    private let tickLabelBottom: CGFloat = 3

    init(reading: ThermalReading) {
        self.reading = reading
        super.init(frame: NSRect(
            x: 0, y: 0, width: MenuMetrics.rowWidth, height: MenuMetrics.scaleRowHeight
        ))
        wantsLayer = true
        // The needle paints itself in `draw(_:)` rather than relying on a
        // layer background color: a layer's own fill is composited only where
        // the compositor runs, so a color set on a layer would vanish in any
        // draw path that is not a live window.
        needle.wantsLayer = true
        needle.isHidden = reading.temperatureC == nil
        addSubview(needle)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - Geometry

    private var usableWidth: CGFloat {
        bounds.width - MenuMetrics.insetLeading - MenuMetrics.insetTrailing
    }

    private func trackX(forFraction fraction: Double) -> CGFloat {
        MenuMetrics.insetLeading + usableWidth * CGFloat(min(max(fraction, 0), 1))
    }

    private func needleX(forFraction fraction: Double) -> CGFloat {
        trackX(forFraction: fraction) - needleWidth / 2
    }

    private var needleFrameY: CGFloat { trackCenterY - needleHeight / 2 }

    private func placeNeedle(atFraction fraction: Double) {
        needle.frame = NSRect(
            x: needleX(forFraction: fraction),
            y: needleFrameY,
            width: needleWidth,
            height: needleHeight
        )
    }

    private func layoutNeedle() {
        guard let temperature = reading.temperatureC else { return }
        placeNeedle(atFraction: ThermalScale.fraction(temperature))
    }

    override func layout() {
        super.layout()
        if entrancePlayed { return }
        layoutNeedle()
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        let trackRect = NSRect(
            x: MenuMetrics.insetLeading,
            y: trackCenterY - trackThickness / 2,
            width: usableWidth,
            height: trackThickness
        )
        NSColor.separatorColor.setFill()
        NSBezierPath(roundedRect: trackRect, xRadius: trackThickness / 2, yRadius: trackThickness / 2).fill()

        if reading.tier != .muted {
            let band = ThermalScale.band(reading.tier)
            let from = trackX(forFraction: band.lowerBound)
            let to = trackX(forFraction: band.upperBound)
            let bandRect = NSRect(
                x: from,
                y: trackRect.minY,
                width: max(to - from, trackThickness),
                height: trackThickness
            )
            StatusStyle.color(for: reading.tier).setFill()
            NSBezierPath(roundedRect: bandRect, xRadius: trackThickness / 2, yRadius: trackThickness / 2).fill()
        }

        NSColor.secondaryLabelColor.setFill()
        for tick in ThermalScale.ticks {
            let x = trackX(forFraction: tick.fraction)
            NSBezierPath(rect: NSRect(
                x: x - 0.75,
                y: trackCenterY - tickLength / 2,
                width: 1.5,
                height: tickLength
            )).fill()
            let label = NSAttributedString(string: tick.label, attributes: [
                .font: MenuMetrics.tickFont(),
                .foregroundColor: NSColor.secondaryLabelColor,
            ])
            label.draw(at: NSPoint(x: x - label.size().width / 2, y: tickLabelBottom))
        }
    }

    // MARK: - The one authored motion

    /// As the menu opens, the needle slides in from the left of the scale to
    /// the live reading — a gauge settling, once per open. Under Reduce Motion
    /// it simply appears at its reading.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { playEntrance() }
    }

    private func playEntrance() {
        guard !entrancePlayed, let temperature = reading.temperatureC else { return }
        entrancePlayed = true
        // Layout will not fight the entrance: the needle belongs to the
        // animation until it finishes.
        let readingFraction = ThermalScale.fraction(temperature)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        placeNeedle(atFraction: ThermalScale.fraction(ThermalScale.domainLow))
        if reduceMotion {
            placeNeedle(atFraction: readingFraction)
            needle.alphaValue = 1
            return
        }
        needle.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.24
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.needle.animator().alphaValue = 1
            self.needle.animator().setFrameOrigin(NSPoint(
                x: self.needleX(forFraction: readingFraction),
                y: self.needleFrameY
            ))
        }
    }
}

/// A plain disabled line — the no-battery case, where there is nothing to align.
@MainActor
final class MenuMessageRowView: NSView {
    private let text: NSTextField

    init(_ message: String) {
        text = MenuItemViews.makeLabel(message, font: MenuMetrics.labelFont(), color: .secondaryLabelColor)
        super.init(frame: NSRect(
            x: 0, y: 0, width: MenuMetrics.rowWidth, height: MenuMetrics.messageRowHeight
        ))
        wantsLayer = true
        addSubview(text)
        layoutText()

        setAccessibilityLabel(message)
        setAccessibilityRole(.staticText)
    }

    override func layout() {
        super.layout()
        layoutText()
    }

    private func layoutText() {
        text.frame = NSRect(
            x: MenuMetrics.insetLeading,
            y: 0,
            width: max(0, bounds.width - 2 * MenuMetrics.insetLeading),
            height: MenuMetrics.messageRowHeight
        )
        text.autoresizingMask = [.width]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
