import Foundation

public enum SourceText {
    public static func html(_ html: String) -> String {
        var text = html
        for tag in ["script", "style", "noscript", "svg"] {
            text = text.replacingOccurrences(of: "<" + tag + #"\b[^>]*>[\s\S]*?</"# + tag + #"\s*>"#, with: " ", options: [.regularExpression, .caseInsensitive])
        }
        text = text.replacingOccurrences(of: #"<!--[\s\S]*?-->"#, with: " ", options: .regularExpression)
        if let article = text.range(of: #"<article\b[^>]*>[\s\S]*?</article\s*>"#, options: [.regularExpression, .caseInsensitive]) {
            text = String(text[article])
        }
        text = text.replacingOccurrences(of: #"</?(?:p|h[1-6]|div|br|li|section)\b[^>]*>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        for (entity, value) in ["&nbsp;":" ", "&amp;":"&", "&quot;":"\"", "&apos;":"'", "&lt;":"<", "&gt;":">"] { text = text.replacingOccurrences(of: entity, with: value) }
        if let expression = try? NSRegularExpression(pattern: #"&#(x[0-9a-fA-F]+|[0-9]+);"#) {
            let mutable = NSMutableString(string: text)
            for match in expression.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length)).reversed() {
                let code = (text as NSString).substring(with: match.range(at: 1))
                let number = code.hasPrefix("x") ? UInt32(code.dropFirst(), radix: 16) : UInt32(code)
                if let number, let scalar = UnicodeScalar(number) { mutable.replaceCharacters(in: match.range, with: String(scalar)) }
            }
            text = mutable as String
        }
        text = text.replacingOccurrences(of: #"[^\S\n]+"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\n\s*\n+"#, with: "\n\n", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
