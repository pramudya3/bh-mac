import Foundation

/// One row of the status menu, as data. `MenuBarController` (the AppKit
/// layer) renders these; everything here is pure so it can be tested.
enum MenuRow: Equatable {
    case info(String)
    case action(String, keyEquivalent: String)
    case separator
}
