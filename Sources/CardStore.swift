import AppKit
import Foundation
import SwiftUI

struct CardSnapshot {
    var title: String?
    var description: String?
    var url: String
    var imageURL: String?
    var image: NSImage?
    var siteName: String?
    var ogType: String?
    var twitterCard: String?
    var htmlTruncated: Bool
    var noCardTags: Bool
    var imageError: String?
}

@MainActor
final class CardStore: ObservableObject {
    @Published var urlText = ""
    @Published var menuTitle = "Card Preview"
    @Published var errorMessage: String?
    @Published var persistenceError: String?
    @Published var recents: [String] = []
    @Published var card: CardSnapshot?
    @Published var isFetching = false

    private var fetchGeneration = 0

    init() {
        let loaded = RecentsFile.load()
        recents = RecentsFile.dedupe(loaded.items)
        persistenceError = loaded.error
    }

    func fetch() {
        switch CardFetch.validate(urlText) {
        case .failed(let message):
            errorMessage = message
        case .ok(let url):
            fetchGeneration += 1
            let generation = fetchGeneration
            errorMessage = nil
            isFetching = true
            Task {
                let result = await CardFetch.load(url)
                guard generation == fetchGeneration else { return }
                isFetching = false
                apply(result, requestURL: url)
            }
        }
    }

    func prefillRecent(_ url: String) {
        urlText = url
    }

    func copyTitle() {
        guard let title = card?.title, !title.isEmpty else { return }
        writePasteboard(title)
    }

    func copyURL() {
        guard let url = card?.url else { return }
        writePasteboard(url)
    }

    private func apply(_ result: CardFetch.LoadResult, requestURL: URL) {
        switch result {
        case .failed(let message):
            card = nil
            menuTitle = "Card Preview"
            errorMessage = message
        case .ok(let outcome):
            remember(requestURL.absoluteString)
            errorMessage = outcome.regexFailed ? "Internal regex failed." : nil
            var image: NSImage?
            var imageError = outcome.imageError
            if let data = outcome.imageData {
                if let decoded = NSImage(data: data) {
                    image = decoded
                } else if imageError == nil {
                    imageError = "The image data could not be decoded."
                }
            }
            card = CardSnapshot(
                title: outcome.title,
                description: outcome.description,
                url: outcome.url,
                imageURL: outcome.imageURL,
                image: image,
                siteName: outcome.siteName,
                ogType: outcome.ogType,
                twitterCard: outcome.twitterCard,
                htmlTruncated: outcome.htmlTruncated,
                noCardTags: outcome.noCardTags,
                imageError: imageError
            )
            menuTitle = Self.truncatedTitle(outcome.title)
        }
    }

    private func remember(_ url: String) {
        recents.removeAll { $0 == url }
        recents.insert(url, at: 0)
        if recents.count > RecentsFile.cap {
            recents = Array(recents.prefix(RecentsFile.cap))
        }
        do {
            try RecentsFile.save(recents)
            persistenceError = nil
        } catch {
            persistenceError = error.localizedDescription
        }
    }

    private func writePasteboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    private static func truncatedTitle(_ title: String?) -> String {
        guard let title, !title.isEmpty else { return "Card Preview" }
        return String(title.prefix(24))
    }
}

private enum RecentsFile {
    static let displayName = "Card Preview"
    static let cap = 20

    static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/\(displayName)", isDirectory: true)
    }

    static var fileURL: URL {
        directory.appendingPathComponent("recents.json")
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder = JSONDecoder()

    static func load() -> (items: [String], error: String?) {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return ([], nil)
        }
        do {
            let data = try Data(contentsOf: url)
            let items = try decoder.decode([String].self, from: data)
            return (items, nil)
        } catch {
            return ([], error.localizedDescription)
        }
    }

    static func save(_ items: [String]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let trimmed = Array(items.prefix(cap))
        let data = try encoder.encode(trimmed)
        try data.write(to: fileURL, options: .atomic)
    }

    static func dedupe(_ items: [String]) -> [String] {
        var seen = Set<String>()
        var unique: [String] = []
        for item in items {
            if seen.insert(item).inserted {
                unique.append(item)
            }
        }
        return Array(unique.prefix(cap))
    }
}
