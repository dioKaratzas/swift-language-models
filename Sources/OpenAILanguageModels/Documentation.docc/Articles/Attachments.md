# Attachments

Send images, PDFs and text with a prompt.

## Overview

Prompts and tool outputs carry images, and from OS 27.2 data attachments too: PDFs and text. A label goes before its
attachment as text, so the model can name it, as an `ImageReference` does:

```swift
let response = try await session.respond {
    "What did I spend on dinner?"
    Attachment(receipt).label("receipt")
}
```

An image goes as an `input_image`, as a JPEG drawn upright from its orientation, on white, and scaled down so that its
longer side is at most 2,048 pixels, with its `detail` set to `auto`. Only its pixels leave the device, never metadata
such as where a photo was taken. An image at a web address goes as that address, when it's upright and its address is
http or https; otherwise the request throws `LanguageModelError.unsupportedTranscriptContent`.

### Attach files

Data attachments need Xcode 27.2 at build time, since earlier SDKs lack them. ``FileAttachment``, from the
`LanguageModels` module, reads a file and tells its type from its extension, or wraps bytes of a type you name:

```swift
@available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *)
func leaseEnd(of lease: URL, in session: LanguageModelSession) async throws -> String {
    let file = try FileAttachment(contentsOf: lease)
    let response = try await session.respond {
        "When does the lease end?"
        Attachment(file).label(lease.lastPathComponent)
    }
    return response.content
}
```

``FileAttachment/init(contentsOf:)`` throws ``FileAttachment/UnknownTypeError`` for a file whose extension names no type
the system knows, such as one without an extension; pass the type yourself with ``FileAttachment/init(_:type:)``.

- An image file, such as a PNG or HEIC file, goes as an image attachment does.
- A PDF goes as an `input_file`, named by its label, with `.pdf` added when the label lacks it, or `document.pdf`
  without a label.
- Plain text goes as text.
- Audio and video aren't taken: a request with either throws `LanguageModelError.unsupportedTranscriptContent`
  before sending anything.

### Check what a model takes

``OpenAIModel/inputModalities`` lists the kinds a model takes: `text`, `image` and `pdf`. GPT-6 Luna takes all three,
and GPT-5.2 takes text and images, but not PDFs. `supportsDataAttachmentType(_:)` says whether the model takes a kind
of data:

```swift
print(OpenAIModel.gpt6Luna.supportsDataAttachmentType(.pdf))  // true
print(OpenAIModel.gpt5_2.supportsDataAttachmentType(.pdf))  // false
print(OpenAIModel.gpt6Luna.supportsDataAttachmentType(.wav))  // false
```

When the model doesn't take an attachment, a request throws before sending anything:
`LanguageModelError.unsupportedCapability` with `.vision` for an image attachment, and
`LanguageModelError.unsupportedTranscriptContent` for a data attachment, an image file included. Instructions take
only text, so an attachment there throws `unsupportedTranscriptContent` too. An image OpenAI rejects, such as one too
large or in a format it can't read, throws `unsupportedTranscriptContent`, naming the entries with images.
<doc:Mapping#Requests> lists the part each kind of attachment becomes.

Generated data and an answer's attachments stay in the transcript but aren't sent back. Each request sends the whole
transcript, so a prompt's attachment goes again with every later request of the session.

### Apple's guides

- [Analyzing images with multimodal prompting](https://developer.apple.com/documentation/foundationmodels/analyzing-images-with-multimodal-prompting)
- [Attachment](https://developer.apple.com/documentation/foundationmodels/attachment),
  [ImageReference](https://developer.apple.com/documentation/foundationmodels/imagereference) and
  [DataAttachmentRepresentable](https://developer.apple.com/documentation/foundationmodels/dataattachmentrepresentable)
