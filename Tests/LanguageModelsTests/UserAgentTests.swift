import Foundation
import LanguageModels
import Testing

@Suite("User-Agent")
struct UserAgentTests {
    @Test func `the package leads, then the app, Swift and the operating system`() {
        let value = UserAgent.value(app: "com.example.Planner/2.3", swiftVersion: "6.4", system: "iOS/27.0.1")

        #expect(value == "swift-language-models (com.example.Planner/2.3; Swift/6.4; iOS/27.0.1)")
    }

    @Test func `without an app, the comment starts at Swift`() {
        let value = UserAgent.value(app: nil, swiftVersion: "6.4", system: "macOS/27.2.0")

        #expect(value == "swift-language-models (Swift/6.4; macOS/27.2.0)")
    }

    @Test func `this process names the package, Swift and macOS, and no app, since tests run outside one`() {
        let pattern = /swift-language-models \(Swift\/\d+\.\d+; macOS\/\d+\.\d+\.\d+\)/

        #expect(UserAgent.current.wholeMatch(of: pattern) != nil)
    }

    @Test(arguments: [
        ("Planner.app", ["CFBundleIdentifier": "com.example.Planner", "CFBundleShortVersionString": "2.3"], "com.example.Planner/2.3"),
        ("Widget.appex", ["CFBundleIdentifier": "com.example.Planner.Widget"], "com.example.Planner.Widget"),
        ("Planner.framework", ["CFBundleIdentifier": "com.example.PlannerKit", "CFBundleShortVersionString": "1.0"], nil),
    ])
    func `an app or app extension names its bundle id and version, and any other bundle nothing`(
        name: String,
        info: [String: String],
        app: String?
    ) throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: name)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let contents = url.appending(path: "Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try plist.write(to: contents.appending(path: "Info.plist"))
        let bundle = try #require(Bundle(url: url))

        #expect(UserAgent.app(of: bundle) == app)
    }
}
