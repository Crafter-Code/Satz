import Foundation
import PDFKit
import SatzCore

enum SourceReader {
    static let trustedHosts = ["apple.com", "nasa.gov", "noaa.gov", "nist.gov", "usgs.gov", "tourismdepartment.gov.np", "dos.gov.np", "gov.uk", "europa.eu", "who.int", "un.org", "esa.int"]
    static func allowed(_ value: String) -> Bool {
        guard FactLibrary.validSource(value), let host = URL(string: value)?.host?.lowercased() else { return false }
        return trustedHosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }
    static func normalized(_ text: String) -> String {
        text.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
    }
    static func download(_ source: String) async throws -> String {
        guard allowed(source), let url = URL(string: source) else { throw URLError(.unsupportedURL) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil; configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 25
        let delegate = SameHostRedirectDelegate(host: url.host!)
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url)
        request.setValue("Satz/0.1 (manual source check)", forHTTPHeaderField: "User-Agent")
        let (stream, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              http.expectedContentLength <= 20_000_000 else { throw URLError(.badServerResponse) }
        var bytes = Data()
        for try await byte in stream {
            guard bytes.count < 20_000_000 else { throw URLError(.dataLengthExceedsMaximum) }
            bytes.append(byte)
        }
        let text: String
        if response.mimeType == "application/pdf" || url.pathExtension.lowercased() == "pdf" {
            guard let document = PDFDocument(data: bytes), let extracted = document.string else { throw URLError(.cannotDecodeContentData) }
            text = extracted
        } else {
            guard let html = String(data: bytes, encoding: .utf8) else { throw URLError(.cannotDecodeContentData) }
            text = SourceText.html(html)
        }
        return String(text.prefix(250_000))
    }
    static func check(_ fact: SourceFact) async throws -> Bool {
        let text = try await download(fact.source)
        let answer = normalized(fact.answer)
        guard answer.count >= 3 else { return false }
        return normalized(text).contains(answer)
    }
}

private final class SameHostRedirectDelegate: NSObject, URLSessionTaskDelegate {
    let host: String
    init(host: String) { self.host = host }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request.url?.host == host && request.url?.scheme == "https" ? request : nil)
    }
}
