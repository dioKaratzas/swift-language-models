import LanguageModels
import Testing

/// The level is shared by the whole process, so these tests run one at a time and restore it.
@Suite("Logging level", .serialized)
struct LanguageModelsLoggingTests {
    @Test func `the package logs every level unless the app sets one`() {
        #expect(LanguageModelsLogging.level == .debug)
    }

    @Test func `levels rise in severity from debug to off`() {
        let levels: [LanguageModelsLogging.Level] = [.debug, .info, .notice, .error, .fault, .off]

        #expect(levels.sorted() == levels)
        #expect(levels.sorted(by: >) == levels.reversed())
    }

    @Test(arguments: [
        (LanguageModelsLogging.Level.debug, [LanguageModelsLogging.Level.debug, .info, .notice, .error, .fault]),
        (.info, [.info, .notice, .error, .fault]),
        (.error, [.error, .fault]),
        (.fault, [.fault]),
        (.off, []),
    ])
    func `a category writes only at the app's level and the more severe ones`(
        level: LanguageModelsLogging.Level,
        written: [LanguageModelsLogging.Level]
    ) {
        let category = PackageLogger(category: "Tests")
        LanguageModelsLogging.level = level
        defer { LanguageModelsLogging.level = .debug }

        let levels: [LanguageModelsLogging.Level] = [.debug, .info, .notice, .error, .fault]
        #expect(levels.filter { category($0) != nil } == written)
    }

    @Test func `any task can set and read the level at once`() async {
        defer { LanguageModelsLogging.level = .debug }

        await withTaskGroup(of: LanguageModelsLogging.Level.self) { group in
            for index in 0..<100 {
                group.addTask {
                    LanguageModelsLogging.level = index.isMultiple(of: 2) ? .error : .off
                    return LanguageModelsLogging.level
                }
            }
            for await level in group {
                #expect([.error, .off].contains(level))
            }
        }
    }
}
