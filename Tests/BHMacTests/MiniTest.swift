//
// MiniTest.swift
//
// This machine's CommandLineTools install (6.4) has no XCTest module and no
// swift-testing runtime, so `swift test` cannot build a testTarget. This
// minimal harness replaces it: same assertion vocabulary, same test names,
// same RED->GREEN discipline. Run: `swift run --build-system native bhmac-tests`
//

import Foundation

/// Runner instance holds the only mutable test state (Swift 6 mode forbids
/// mutable globals). Harness is single-threaded by construction, hence
/// @unchecked Sendable. Static facade below keeps call sites terse.
final class MiniTestRunner: @unchecked Sendable {
    static let shared = MiniTestRunner()

    private var currentSuite = ""
    private var currentTest = ""
    private var failures: [String] = []
    private var assertionCount = 0
    private var testCount = 0
    private var failedTests: [String] = []
    private var skippedTests: [String] = []
    private var skipReasons: [String: String] = [:]
    private var skipRequested = false

    func suite(_ name: String) {
        currentSuite = name
    }

    func test(_ name: String, _ body: () -> Void) {
        currentTest = "\(currentSuite).\(name)"
        testCount += 1
        skipRequested = false
        let failuresBefore = failures.count
        body()
        if skipRequested {
            skippedTests.append(currentTest)
        } else if failures.count > failuresBefore {
            failedTests.append(currentTest)
        }
    }

    func skip(_ reason: String) {
        skipRequested = true
        skipReasons[currentTest] = reason
    }

    func expect(_ condition: Bool, _ message: String = "expectation failed") {
        assertionCount += 1
        if !condition {
            failures.append("\(currentTest): \(message)")
        }
    }

    func reportAndExit() -> Never {
        for line in failures {
            FileHandle.standardError.write((line + "\n").data(using: .utf8)!)
        }
        for name in failedTests {
            FileHandle.standardError.write("FAILED: \(name)\n".data(using: .utf8)!)
        }
        for name in skippedTests {
            let reason = skipReasons[name] ?? ""
            FileHandle.standardError.write("SKIPPED: \(name) — \(reason)\n".data(using: .utf8)!)
        }
        let verdict = failures.isEmpty ? "PASS" : "FAIL"
        print("MiniTest: \(testCount) tests (\(skippedTests.count) skipped), \(assertionCount) assertions, \(failures.count) failures -> \(verdict)")
        exit(failures.isEmpty ? 0 : 1)
    }
}

enum MiniTest {
    static func suite(_ name: String) {
        MiniTestRunner.shared.suite(name)
    }

    static func test(_ name: String, _ body: () -> Void) {
        MiniTestRunner.shared.test(name, body)
    }

    static func skip(_ reason: String) {
        MiniTestRunner.shared.skip(reason)
    }

    static func expect(_ condition: Bool, _ message: String = "expectation failed") {
        MiniTestRunner.shared.expect(condition, message)
    }

    static func reportAndExit() -> Never {
        MiniTestRunner.shared.reportAndExit()
    }
}

func expectEqual<T: Equatable>(_ actual: T?, _ expected: T?, _ line: UInt = #line) {
    MiniTest.expect(
        actual == expected,
        "line \(line): expected \(String(describing: expected)), got \(String(describing: actual))"
    )
}

func expectClose(_ actual: Double?, _ expected: Double, accuracy: Double, _ line: UInt = #line) {
    guard let actual else {
        MiniTest.expect(false, "line \(line): expected \(expected)±\(accuracy), got nil")
        return
    }
    MiniTest.expect(
        abs(actual - expected) <= accuracy,
        "line \(line): expected \(expected)±\(accuracy), got \(actual)"
    )
}
