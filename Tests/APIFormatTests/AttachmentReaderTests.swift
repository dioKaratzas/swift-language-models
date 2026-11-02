import APIFormat
import Testing

@Suite("Attachment reader")
struct AttachmentReaderTests {
    @Test func `images go no larger than 2,048 pixels on their longer side`() {
        #expect(AttachmentReader(provider: "Test").maximumImageSide == 2_048)
    }
}
