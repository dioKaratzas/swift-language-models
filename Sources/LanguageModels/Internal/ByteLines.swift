/// The lines of a byte stream, split only at line feeds, each without its line break.
///
/// `URLSession.AsyncBytes.lines` also splits at Unicode line breaks such as U+2028, which JSON may carry unescaped
/// inside a string, so one server-sent event could arrive as two broken halves.
package struct ByteLines<Base: AsyncSequence>: AsyncSequence where Base.Element == UInt8 {
    package typealias Element = String
    package typealias Failure = Base.Failure

    private let base: Base

    /// The lines of a byte stream.
    ///
    /// - Parameter base: The bytes, such as a response body.
    package init(_ base: Base) {
        self.base = base
    }

    package func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(base: base.makeAsyncIterator())
    }

    package struct AsyncIterator: AsyncIteratorProtocol {
        private var base: Base.AsyncIterator
        private var isFinished = false

        fileprivate init(base: Base.AsyncIterator) {
            self.base = base
        }

        package mutating func next(isolation actor: isolated (any Actor)? = #isolation) async throws(Base.Failure) -> String? {
            guard !isFinished else { return nil }
            var line: [UInt8] = []
            while let byte = try await base.next(isolation: actor) {
                if byte == 0x0A { return Self.text(line) }
                line.append(byte)
            }
            isFinished = true
            return line.isEmpty ? nil : Self.text(line)
        }

        package mutating func next() async throws(Base.Failure) -> String? {
            try await next(isolation: nil)
        }

        /// A line's text, without a carriage return before its line feed.
        private static func text(_ line: [UInt8]) -> String {
            String(decoding: line.last == 0x0D ? line.dropLast() : line[...], as: UTF8.self)
        }
    }
}
