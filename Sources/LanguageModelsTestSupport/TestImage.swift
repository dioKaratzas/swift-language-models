package import CoreGraphics
package import Foundation
package import ImageIO
package import UniformTypeIdentifiers

/// Images drawn in code, so tests need no image files.
package enum TestImage {
    /// An image whose left half is red and right half blue, so a test can tell how it was turned.
    ///
    /// - Parameters:
    ///   - width: The width in pixels.
    ///   - height: The height in pixels.
    /// - Returns: The image, or `nil` when Core Graphics can't draw it.
    package static func halves(width: Int, height: Int) -> CGImage? {
        draw(width: width, height: height) { context in
            context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
            context.setFillColor(red: 0, green: 0, blue: 1, alpha: 1)
            context.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))
        }
    }

    /// A thick black digit 7 on white, for a model to read.
    ///
    /// - Parameter size: The width and height in pixels.
    /// - Returns: The image, or `nil` when Core Graphics can't draw it.
    package static func seven(size: Int) -> CGImage? {
        let side = Double(size)
        return draw(width: size, height: size) { context in
            context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            context.setStrokeColor(red: 0, green: 0, blue: 0, alpha: 1)
            context.setLineWidth(side / 9)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            // Core Graphics' y grows upward: the bar runs along the top, and the stroke falls to the bottom left.
            context.move(to: CGPoint(x: side * 0.25, y: side * 0.8))
            context.addLine(to: CGPoint(x: side * 0.75, y: side * 0.8))
            context.addLine(to: CGPoint(x: side * 0.4, y: side * 0.15))
            context.strokePath()
        }
    }

    /// An image as a file of a kind ImageIO writes, such as PNG or HEIC.
    ///
    /// - Parameters:
    ///   - image: The pixels.
    ///   - type: The kind of file.
    ///   - orientation: The orientation the file records, which a reader applies to turn the pixels upright.
    /// - Returns: The file's bytes, or `nil` when ImageIO can't write the kind.
    package static func file(of image: CGImage, as type: UTType, orientation: CGImagePropertyOrientation = .up) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: orientation.rawValue] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    /// Draws into an opaque sRGB canvas, with Core Graphics' y growing upward.
    private static func draw(width: Int, height: Int, _ drawing: (CGContext) -> Void) -> CGImage? {
        // Without a buffer of its own, the context allocates and owns its memory, so no pointer is ever used.
        guard
            let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = unsafe CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        drawing(context)
        return context.makeImage()
    }
}

/// An image file's pixels, decoded, so a test can check its size and where its colors are.
package struct DecodedImage {
    /// The width in pixels.
    package let width: Int

    /// The height in pixels.
    package let height: Int

    private let pixels: Data
    private let bytesPerRow: Int

    /// Decodes an image file, without applying the orientation it records, or fails when ImageIO can't read the data.
    ///
    /// - Parameter data: The file's bytes, such as a JPEG.
    package init?(_ data: Data) {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
            let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = unsafe CGContext(
                data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let pixels = context.makeImage()?.dataProvider?.data else { return nil }
        self.width = image.width
        self.height = image.height
        self.pixels = pixels as Data
        self.bytesPerRow = image.width * 4
    }

    /// The color of a pixel, counted from the top left, each component from 0 to 255.
    package func color(x: Int, y: Int) -> (red: Int, green: Int, blue: Int) {
        let offset = y * bytesPerRow + x * 4
        return (Int(pixels[offset]), Int(pixels[offset + 1]), Int(pixels[offset + 2]))
    }

    /// Whether a pixel is mostly red, allowing for JPEG's loss.
    package func isRed(x: Int, y: Int) -> Bool {
        let color = color(x: x, y: y)
        return color.red > 200 && color.green < 60 && color.blue < 60
    }

    /// Whether a pixel is mostly blue, allowing for JPEG's loss.
    package func isBlue(x: Int, y: Int) -> Bool {
        let color = color(x: x, y: y)
        return color.blue > 200 && color.red < 60 && color.green < 60
    }
}
