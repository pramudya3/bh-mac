import AppKit
@testable import BHMac

@MainActor
enum StatusStyleTests {
    static func run() {
        MiniTest.suite("StatusStyleTests")

        MiniTest.test("testStatusItemColorIsNeutral") {
            // The menu bar is glanced at constantly; the alarm lives one
            // click deep in the dropdown. Neutral for every tier, no
            // exceptions, including muted.
            expectEqual(StatusStyle.statusItemColor, NSColor.labelColor)
        }

        MiniTest.test("testTierColors") {
            expectEqual(StatusStyle.color(for: TempTier.muted), NSColor.secondaryLabelColor)
            expectEqual(StatusStyle.color(for: TempTier.normal), NSColor.systemGreen)
            expectEqual(StatusStyle.color(for: TempTier.warm), NSColor.systemOrange)
            expectEqual(StatusStyle.color(for: TempTier.hot), NSColor.systemRed)
        }

        MiniTest.test("testHealthConditionColorsShareTheAlarmPalette") {
            expectEqual(StatusStyle.color(for: HealthCondition.normal), NSColor.systemGreen)
            expectEqual(StatusStyle.color(for: HealthCondition.replaceSoon), NSColor.systemOrange)
            expectEqual(StatusStyle.color(for: HealthCondition.service), NSColor.systemRed)
        }

        MiniTest.test("testStatusSymbolResolvesAndBailsOnGarbage") {
            MiniTest.expect(
                StatusStyle.statusSymbol(named: MenuContentFactory.statusSymbolName, pointSize: 11) != nil,
                "the status item's glyph must resolve"
            )
            expectEqual(StatusStyle.statusSymbol(named: "", pointSize: 11), nil)
        }

        MiniTest.test("testMeasurementVoiceIsFixedPitch") {
            // Every measured number in the app wears one monospaced face, so
            // columns align and no reading reflows as its digits change.
            MiniTest.expect(MenuMetrics.measurementFont().isFixedPitch)
            MiniTest.expect(MenuMetrics.tickFont().isFixedPitch)
        }

        MiniTest.test("testStatusTitleDigitsAreTabular") {
            let width = { (string: String) -> CGFloat in
                NSAttributedString(string: string, attributes: [.font: MenuMetrics.titleFont()]).size().width
            }
            // Tabular figures: 1s and 8s cost the same, so the menu-bar item
            // never jitters as the temperature changes.
            expectClose(width("1111"), width("8888"), accuracy: 0.5)
        }

        MiniTest.test("testValueAttributedStringUsesBothVoices") {
            let composed = MenuItemViews.valueAttributedString(
                MenuValue(measurement: "80%", note: "Normal", signal: .health(.normal))
            )
            expectEqual(composed.string, "80% · Normal")
            var effective = NSRange(location: 0, length: 0)
            let measurementFont = composed.attribute(.font, at: 0, effectiveRange: &effective) as? NSFont
            let noteFont = composed.attribute(.font, at: 5, effectiveRange: &effective) as? NSFont
            // The number wears the measurement face, the word the human face.
            MiniTest.expect(measurementFont?.fontName.contains("Mono") == true)
            MiniTest.expect(noteFont?.fontName.contains("Mono") == false)
        }
    }
}
