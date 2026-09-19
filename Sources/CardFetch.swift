import Foundation

enum CardFetch {
    static let htmlLimit = 1_048_576
    static let imageLimit = 5_242_880
    static let userAgent = "CardPreview/1.0 (engineer.badry.cardpreview)"

    enum LoadResult {
        case failed(String)
        case ok(Outcome)
    }

    enum Validation {
        case failed(String)
        case ok(URL)
    }

    struct Outcome {
        var title: String?
        var description: String?
        var url: String
        var imageURL: String?
        var imageData: Data?
        var imageError: String?
        var siteName: String?
        var ogType: String?
        var twitterCard: String?
        var htmlTruncated: Bool
        var noCardTags: Bool
        var regexFailed: Bool
    }

    static func validate(_ raw: String) -> Validation {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else {
            return .failed("Invalid URL")
        }
        guard let scheme = url.scheme, !scheme.isEmpty else {
            return .failed("Invalid URL")
        }
        let lowered = scheme.lowercased()
        guard lowered == "http" || lowered == "https" else {
            return .failed("URL must be http or https.")
        }
        return .ok(url)
    }

    static func load(_ url: URL) async -> LoadResult {
        let session = makeSession()
        defer { session.finishTasksAndInvalidate() }
        let htmlDownload: (data: Data, truncated: Bool, response: URLResponse)
        do {
            htmlDownload = try await cappedGET(session: session, url: url, limit: htmlLimit)
        } catch {
            return .failed(error.localizedDescription)
        }
        let pageURL = htmlDownload.response.url ?? url
        let html = String(decoding: htmlDownload.data, as: UTF8.self)
        var parsed = parse(html, pageURL: pageURL, requestURL: url)
        parsed.htmlTruncated = htmlDownload.truncated
        if let imageURL = parsed.imageURL, let fetchURL = URL(string: imageURL) {
            let scheme = fetchURL.scheme?.lowercased() ?? ""
            if scheme != "http" && scheme != "https" {
                parsed.imageError = "URL must be http or https."
            } else {
                do {
                    let imageDownload = try await cappedGET(session: session, url: fetchURL, limit: imageLimit)
                    parsed.imageData = imageDownload.data
                } catch {
                    parsed.imageError = error.localizedDescription
                }
            }
        }
        return .ok(parsed)
    }

    private static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.httpAdditionalHeaders = ["User-Agent": userAgent]
        return URLSession(configuration: config)
    }

    private static func cappedGET(session: URLSession, url: URL, limit: Int) async throws -> (data: Data, truncated: Bool, response: URLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        let (asyncBytes, response) = try await session.bytes(for: request)
        var truncated = false
        if let http = response as? HTTPURLResponse,
           let header = http.value(forHTTPHeaderField: "Content-Length"),
           let length = Int(header),
           length > limit {
            truncated = true
        }
        var data = Data()
        data.reserveCapacity(min(limit, 65_536))
        var iterator = asyncBytes.makeAsyncIterator()
        while data.count < limit {
            do {
                guard let byte = try await iterator.next() else {
                    return (data, truncated, response)
                }
                data.append(byte)
            } catch {
                throw error
            }
        }
        do {
            if try await iterator.next() != nil {
                truncated = true
            }
        } catch {
            let nsError = error as NSError
            if truncated && nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                asyncBytes.task.cancel()
                return (data, true, response)
            }
            asyncBytes.task.cancel()
            throw error
        }
        asyncBytes.task.cancel()
        return (data, truncated, response)
    }

    private static func parse(_ html: String, pageURL: URL, requestURL: URL) -> Outcome {
        var regexFailed = false
        var metas: [String: String] = [:]
        collectMetas(
            pattern: #"<meta[^>]*(?:property|name)\s*=\s*["']((?:og|twitter):[^"']+)["'][^>]*content\s*=\s*["']([^"']*)["'][^>]*>"#,
            html: html,
            keyIndex: 1,
            valueIndex: 2,
            into: &metas,
            regexFailed: &regexFailed
        )
        collectMetas(
            pattern: #"<meta[^>]*content\s*=\s*["']([^"']*)["'][^>]*(?:property|name)\s*=\s*["']((?:og|twitter):[^"']+)["'][^>]*>"#,
            html: html,
            keyIndex: 2,
            valueIndex: 1,
            into: &metas,
            regexFailed: &regexFailed
        )

        let htmlTitleRaw = firstCapture(
            pattern: #"<title>([^<]+)</title>"#,
            in: html,
            regexFailed: &regexFailed
        )
        let canonicalRaw = firstCapture(
            pattern: #"<link[^>]*rel\s*=\s*["']canonical["'][^>]*href\s*=\s*["']([^"']+)["']"#,
            in: html,
            regexFailed: &regexFailed
        ) ?? firstCapture(
            pattern: #"<link[^>]*href\s*=\s*["']([^"']+)["'][^>]*rel\s*=\s*["']canonical["']"#,
            in: html,
            regexFailed: &regexFailed
        )

        func decodedMeta(_ key: String) -> String? {
            guard let raw = metas[key] else { return nil }
            let value = decodeEntities(raw, regexFailed: &regexFailed)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }

        let ogTitle = decodedMeta("og:title")
        let twitterTitle = decodedMeta("twitter:title")
        let ogDescription = decodedMeta("og:description")
        let twitterDescription = decodedMeta("twitter:description")
        let ogImage = decodedMeta("og:image")
        let twitterImage = decodedMeta("twitter:image")
        let ogURL = decodedMeta("og:url")
        let siteName = decodedMeta("og:site_name")
        let ogType = decodedMeta("og:type")
        let twitterCard = decodedMeta("twitter:card")

        let htmlTitle: String?
        if let htmlTitleRaw {
            let value = decodeEntities(htmlTitleRaw, regexFailed: &regexFailed)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            htmlTitle = value.isEmpty ? nil : value
        } else {
            htmlTitle = nil
        }

        let noCardTags = ogTitle == nil && twitterTitle == nil
            && ogDescription == nil && twitterDescription == nil
            && ogImage == nil && twitterImage == nil

        let title = ogTitle ?? twitterTitle ?? htmlTitle
        let description = ogDescription ?? twitterDescription

        let resolvedURL: String
        if let ogURL, let resolved = URL(string: ogURL, relativeTo: pageURL) {
            resolvedURL = resolved.absoluteString
        } else if let canonicalRaw {
            let canonical = decodeEntities(canonicalRaw, regexFailed: &regexFailed)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let resolved = URL(string: canonical, relativeTo: pageURL) {
                resolvedURL = resolved.absoluteString
            } else {
                resolvedURL = requestURL.absoluteString
            }
        } else {
            resolvedURL = requestURL.absoluteString
        }

        var imageURL: String?
        if let raw = ogImage ?? twitterImage {
            if let resolved = URL(string: raw, relativeTo: pageURL) {
                imageURL = resolved.absoluteString
            } else {
                imageURL = raw
            }
        }

        return Outcome(
            title: title,
            description: description,
            url: resolvedURL,
            imageURL: imageURL,
            imageData: nil,
            imageError: nil,
            siteName: siteName,
            ogType: ogType,
            twitterCard: twitterCard,
            htmlTruncated: false,
            noCardTags: noCardTags,
            regexFailed: regexFailed
        )
    }

    private static func collectMetas(
        pattern: String,
        html: String,
        keyIndex: Int,
        valueIndex: Int,
        into metas: inout [String: String],
        regexFailed: inout Bool
    ) {
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        } catch {
            regexFailed = true
            return
        }
        let fullRange = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: fullRange)
        for match in matches {
            let maxIndex = max(keyIndex, valueIndex)
            guard match.numberOfRanges > maxIndex,
                  let keyRange = Range(match.range(at: keyIndex), in: html),
                  let valueRange = Range(match.range(at: valueIndex), in: html) else {
                continue
            }
            let key = String(html[keyRange]).lowercased()
            if metas[key] == nil {
                metas[key] = String(html[valueRange])
            }
        }
    }

    private static func firstCapture(pattern: String, in html: String, regexFailed: inout Bool) -> String? {
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        } catch {
            regexFailed = true
            return nil
        }
        let fullRange = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: fullRange),
              match.numberOfRanges >= 2,
              let capture = Range(match.range(at: 1), in: html) else {
            return nil
        }
        return String(html[capture])
    }

    private static func decodeEntities(_ raw: String, regexFailed: inout Bool) -> String {
        var text = replaceNumeric(pattern: #"&#([0-9]+);"#, in: raw, regexFailed: &regexFailed) { digits in
            guard let value = Int(digits), let scalar = UnicodeScalar(value) else { return nil }
            return String(Character(scalar))
        }
        text = replaceNumeric(pattern: #"&#x([0-9a-fA-F]+);"#, in: text, regexFailed: &regexFailed) { hex in
            guard let value = Int(hex, radix: 16), let scalar = UnicodeScalar(value) else { return nil }
            return String(Character(scalar))
        }
        let named: [(String, String)] = [
            ("&nbsp;", "\u{00A0}"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&#39;", "'"),
            ("&amp;", "&"),
        ]
        for (needle, replacement) in named {
            var searchFrom = text.startIndex
            while searchFrom < text.endIndex,
                  let range = text.range(of: needle, options: [.caseInsensitive], range: searchFrom..<text.endIndex) {
                text.replaceSubrange(range, with: replacement)
                searchFrom = text.index(range.lowerBound, offsetBy: replacement.count)
            }
        }
        return text
    }

    private static func replaceNumeric(
        pattern: String,
        in text: String,
        regexFailed: inout Bool,
        convert: (String) -> String?
    ) -> String {
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        } catch {
            regexFailed = true
            return text
        }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        var result = text
        for match in matches.reversed() {
            guard match.numberOfRanges >= 2,
                  let whole = Range(match.range, in: result),
                  let capture = Range(match.range(at: 1), in: result) else {
                continue
            }
            let digits = String(result[capture])
            if let replacement = convert(digits) {
                result.replaceSubrange(whole, with: replacement)
            }
        }
        return result
    }
}
