# Card Preview

Preview Open Graph and Twitter card tags for a page, including the image.

Menu extra for macOS 14+. It lives on the **right** of the menu bar and does not show a Dock icon.

| | |
|---|---|
| Product | `CardPreview` |
| Bundle ID | `engineer.badry.cardpreview` |
| Status item | SF Symbol `photo.on.rectangle` |
| Panel | opaque ~360×420 pt |

## Features

- GET `http` / `https` only. Other schemes show **URL must be http or https.**
- HTML capped at 1MB; image GET capped at 5MB. Image height max 160 pt.
- Title / description / image / URL from `og:*`, then `twitter:*`, then `<title>` / canonical.
- **Copy title** / **Copy URL**. Recents (cap 20). Menu title is the first 24 graphemes of the title.

## Requirements

- macOS 14 Sonoma or later
- Swift 5.9 or later only if you build from source
- Network for Fetch

## Install

Build from source:

```bash
git clone https://github.com/BadryansahBangsawan/card-preview.git
cd card-preview
bash package-app.sh
ditto dist/CardPreview.app /Applications/CardPreview.app
xattr -cr /Applications/CardPreview.app
open /Applications/CardPreview.app
```

Ad-hoc signed (`codesign -s -`). If Gatekeeper blocks it or says it is damaged, run the `xattr` line above. If still blocked: System Settings → Privacy & Security → Open Anyway.

Do not run `dist/` next to a copy in `/Applications` (same bundle ID).

Enable **Open at Login** from Settings if you want it after reboot.

## How to open

This is an `LSUIElement` extra. Proof it is running is the **photo.on.rectangle** status item on the **right** of the menu bar.

1. Click that extra. The panel is opaque (~360×420), not a 10px strip.
2. If the bar is full, look behind the Control Center overflow chevron **«**.
3. Double-clicking in Finder/Launchpad does not open a document window. That is expected. There is no Dock icon.

## Usage

- Enter an `https://` URL → **Fetch**.
- Missing OG/Twitter tags: red **No Open Graph or Twitter card tags.** (HTML `<title>` still shows if present).
- **Copy title** / **Copy URL**. Tap a recent to prefill.
- **Settings** at the bottom: Open at Login, Quit.

## Permissions

Network only. No Accessibility or Screen Recording.

## Data

Recents: `~/Library/Application Support/Card Preview/recents.json`. Missing file is empty. Decode failure is empty plus a red banner.

## Privacy

Fetch uses an ephemeral `URLSession`. URLs you type stay on this Mac except the HTTP request itself.

## Uninstall

Delete `/Applications/CardPreview.app`. Turn off Open at Login in Settings first if you enabled it.

```bash
rm -rf "$HOME/Library/Application Support/Card Preview"
```

## Troubleshooting

| What you see | What to do |
|---|---|
| No Dock icon | Click the **photo.on.rectangle** extra on the right of the menu bar. |
| Extra missing | Overflow **«**, or `open /Applications/CardPreview.app`. |
| “Damaged” | `xattr -cr /Applications/CardPreview.app` |
| **URL must be http or https.** | Scheme is not `http`/`https`. |
| **No Open Graph or Twitter card tags.** | Page has no `og:` / `twitter:` title, description, or image. |
| **HTML truncated to 1MB.** | Page was larger than 1MB; first megabyte was parsed. |
| Tiny capsule / only Settings | Reinstall from this repo (panel min height 420). |

## Development

```bash
swift build
swift build -c release --product CardPreview
```

Layout: `Sources/` (SwiftPM executable), `Info.plist`, `Assets/AppIcon.icns`, `package-app.sh`. Never commit `dist/`. FunTheme.swift is copied verbatim (no shared package).

## License

[MIT](LICENSE)
