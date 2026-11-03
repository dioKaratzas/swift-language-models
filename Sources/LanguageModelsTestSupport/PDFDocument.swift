package import Foundation

/// A one-page PDF that shows a line of text in Helvetica, written out byte by byte, so tests need no PDF files.
///
/// - Parameter text: The line, in ASCII.
/// - Returns: The PDF's bytes.
package func pdfDocument(showing text: String) -> Data {
    let escaped = text.replacing("\\", with: "\\\\").replacing("(", with: "\\(").replacing(")", with: "\\)")
    let content = "BT /F1 24 Tf 72 720 Td (\(escaped)) Tj ET"
    let objects = [
        "<< /Type /Catalog /Pages 2 0 R >>",
        "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>",
        "<< /Length \(content.utf8.count) >>\nstream\n\(content)\nendstream",
        "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    ]
    var pdf = "%PDF-1.4\n"
    var offsets: [Int] = []
    for (index, object) in objects.enumerated() {
        offsets.append(pdf.utf8.count)
        pdf += "\(index + 1) 0 obj\n\(object)\nendobj\n"
    }
    let table = pdf.utf8.count
    pdf += "xref\n0 \(objects.count + 1)\n0000000000 65535 f \n"
    for offset in offsets {
        pdf += String(repeating: "0", count: 10 - String(offset).count) + "\(offset) 00000 n \n"
    }
    pdf += "trailer\n<< /Size \(objects.count + 1) /Root 1 0 R >>\nstartxref\n\(table)\n%%EOF\n"
    return Data(pdf.utf8)
}
