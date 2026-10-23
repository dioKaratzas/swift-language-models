package import CoreGraphics
package import Foundation
package import ImageIO
package import UniformTypeIdentifiers

/// An image as JPEG bytes for a request: upright, on white, and no larger than a provider's limit.
///
/// The pixels are drawn upright, so the JPEG needs no orientation tag, and on white, so transparent areas don't turn
/// black. An image whose longer side is over the limit is scaled down to it, never up. Only the pixels reach the bytes,
/// never the source's metadata, such as where a photo was taken. The same image gives the same bytes every time, so a
/// provider's prompt cache stays valid when a later request sends it again.
package struct EncodedImage: Sendable, Equatable {
    /// The JPEG quality, from 0 to 1, which keeps small text legible at a fraction of PNG's size.
    package static let quality = 0.85

    /// The image kinds ImageIO reads, which ``init(data:maximumSide:)`` takes.
    package static let readableTypes: Set<UTType> = Set(
        ((CGImageSourceCopyTypeIdentifiers() as? [String]) ?? []).compactMap { UTType($0) }.filter { $0.conforms(to: .image) }
    )

    /// The JPEG bytes.
    package let data: Data

    /// The width of the encoded image, in pixels.
    package let width: Int

    /// The height of the encoded image, in pixels.
    package let height: Int

    /// Encodes decoded pixels, such as a Foundation Models image attachment's, or fails when the image is empty or
    /// ImageIO can't encode it.
    ///
    /// - Parameters:
    ///   - image: The pixels as stored.
    ///   - orientation: How the stored pixels turn upright.
    ///   - maximumSide: The longest side, in pixels, of the encoded image.
    package init?(_ image: CGImage, orientation: CGImagePropertyOrientation, maximumSide: Int) {
        guard image.width > 0, image.height > 0, maximumSide > 0 else { return nil }
        let uprightWidth = orientation.swapsSides ? image.height : image.width
        let uprightHeight = orientation.swapsSides ? image.width : image.height
        let scale = min(1, Double(maximumSide) / Double(max(uprightWidth, uprightHeight)))
        let width = max(1, Int((Double(uprightWidth) * scale).rounded()))
        let height = max(1, Int((Double(uprightHeight) * scale).rounded()))
        // Without a buffer of its own, the context allocates and owns its memory, so no pointer is ever used.
        guard
            let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = unsafe CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.scaleBy(x: Double(width) / Double(uprightWidth), y: Double(height) / Double(uprightHeight))
        context.concatenate(orientation.transform(width: Double(image.width), height: Double(image.height)))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let output = NSMutableData()
        guard
            let pixels = context.makeImage(),
            let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, pixels, [kCGImageDestinationLossyCompressionQuality: Self.quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        self.data = output as Data
        self.width = width
        self.height = height
    }

    /// Decodes an image file's bytes, such as a PNG, HEIC or JPEG, turns them upright by the orientation the file
    /// records, and encodes them, or fails when ImageIO can't read the data or encode the image.
    ///
    /// - Parameters:
    ///   - data: The file's bytes, in a kind of ``readableTypes``.
    ///   - maximumSide: The longest side, in pixels, of the encoded image.
    package init?(data: Data, maximumSide: Int) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        self.init(source, orientation: nil, maximumSide: maximumSide)
    }

    /// Decodes an image file, turns it upright by the given orientation, and encodes it, or fails when ImageIO can't
    /// read the file or encode the image.
    ///
    /// - Parameters:
    ///   - url: The file, in a kind of ``readableTypes``.
    ///   - orientation: How the stored pixels turn upright, which wins over the orientation the file records.
    ///   - maximumSide: The longest side, in pixels, of the encoded image.
    package init?(contentsOf url: URL, orientation: CGImagePropertyOrientation, maximumSide: Int) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        self.init(source, orientation: orientation, maximumSide: maximumSide)
    }

    /// Decodes an image straight at no more than the limit, so a large photo never fills memory at full size, then
    /// turns it upright and encodes it.
    ///
    /// - Parameters:
    ///   - source: The image file.
    ///   - orientation: How the stored pixels turn upright, or `nil` for the orientation the file records.
    ///   - maximumSide: The longest side, in pixels, of the encoded image.
    private init?(_ source: CGImageSource, orientation: CGImagePropertyOrientation?, maximumSide: Int) {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: orientation == nil,
            kCGImageSourceThumbnailMaxPixelSize: maximumSide,
        ]
        guard maximumSide > 0, let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        self.init(image, orientation: orientation ?? .up, maximumSide: maximumSide)
    }
}

extension CGImagePropertyOrientation {
    /// Whether turning the pixels upright swaps their width and height.
    fileprivate var swapsSides: Bool {
        switch self {
        case .leftMirrored, .right, .rightMirrored, .left: true
        default: false
        }
    }

    /// The transform that draws pixels of the given size upright, in Core Graphics' coordinates, where y grows upward.
    fileprivate func transform(width: Double, height: Double) -> CGAffineTransform {
        switch self {
        case .upMirrored: CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: width, ty: 0)
        case .down: CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: width, ty: height)
        case .downMirrored: CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: height)
        case .leftMirrored: CGAffineTransform(a: 0, b: -1, c: -1, d: 0, tx: height, ty: width)
        case .right: CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: width)
        case .rightMirrored: CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0)
        case .left: CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: height, ty: 0)
        default: .identity
        }
    }
}
