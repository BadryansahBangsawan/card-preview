import AppKit
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: CardStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: FunTheme.sectionSpacing) {
            Text("Card Preview")
                .font(.headline)

            TextField("https://example.com", text: $store.urlText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    store.fetch()
                }

            Button("Fetch") {
                store.fetch()
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isFetching)

            if let persistenceError = store.persistenceError {
                Label(persistenceError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let errorMessage = store.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if store.card?.htmlTruncated == true {
                Label("HTML truncated to 1MB.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if store.card?.noCardTags == true {
                Label("No Open Graph or Twitter card tags.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let imageError = store.card?.imageError {
                Label(imageError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let card = store.card {
                cardBlock(card)
            } else {
                ExtraEmptyState(
                    title: "No card yet",
                    detail: "Fetch an http or https page to preview its Open Graph or Twitter card.",
                    actionTitle: "Fetch",
                    action: { store.fetch() }
                )
            }

            if !store.recents.isEmpty {
                recentsBlock
            }

            ExtraSettingsFooter()
        }
        .animation(reduceMotion ? nil : FunTheme.spring, value: store.menuTitle)
        .animation(reduceMotion ? nil : FunTheme.spring, value: store.errorMessage)
        .animation(reduceMotion ? nil : FunTheme.spring, value: store.recents)
        .animation(reduceMotion ? nil : FunTheme.spring, value: store.isFetching)
        .funPanel()
    }

    @ViewBuilder
    private func cardBlock(_ card: CardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: FunTheme.innerSpacing) {
            if let image = card.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 160)
                    .frame(maxWidth: .infinity)
            }
            if let imageURL = card.imageURL {
                Text(imageURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let title = card.title {
                Text(title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let description = card.description {
                Text(description)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(card.url)
                .font(.caption)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            if let siteName = card.siteName {
                Text(siteName)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let ogType = card.ogType {
                Text("og:type  \(ogType)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let twitterCard = card.twitterCard {
                Text("twitter:card  \(twitterCard)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button("Copy title") {
                    store.copyTitle()
                }
                .disabled(card.title == nil || card.title?.isEmpty == true)
                Button("Copy URL") {
                    store.copyURL()
                }
            }
        }
        .extraRowSurface()
    }

    private var recentsBlock: some View {
        VStack(alignment: .leading, spacing: FunTheme.innerSpacing) {
            Text("Recents")
                .font(.headline)
            ForEach(store.recents, id: \.self) { recent in
                Button {
                    store.prefillRecent(recent)
                } label: {
                    Text(recent)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .extraRowSurface()
            }
        }
    }
}
