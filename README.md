<div align="center">

# Card Preview

**Fetch Open Graph and Twitter card tags from an `http`/`https` URL. Title, description, image — or No Open Graph or Twitter card tags.**

Menu extra for macOS 14+. Lives on the **right** of the menu bar. No Dock icon.

<br/>

[![Build](https://github.com/BadryansahBangsawan/card-preview/actions/workflows/ci.yml/badge.svg)](https://github.com/BadryansahBangsawan/card-preview/actions/workflows/ci.yml)
[![Latest Release](https://img.shields.io/github/v/release/BadryansahBangsawan/card-preview?style=flat-square)](https://github.com/BadryansahBangsawan/card-preview/releases/latest)
[![macOS](https://img.shields.io/badge/macOS-14%2B-black?style=flat-square&logo=apple)](https://github.com/BadryansahBangsawan/card-preview/releases/latest)

<br/>

![Card Preview panel](docs/panel.png)

| | |
|---|---|
| Product | `CardPreview` |
| Bundle ID | `engineer.badry.cardpreview` |
| Status item | SF Symbol `photo.on.rectangle` (first 24 graphemes of the page title, or `Card Preview`) |
| Panel | opaque ~360×420 pt |

</div>

---

## What you get

| Piece | Behavior |
|---|---|
| **Fetch** | GET `http` and `https` only. HTML capped at 1 MB. Image GET capped at 5 MB. Image scaled to 160 pt max height. HTTP to HTTPS redirects are followed; other schemes are rejected. |
| **Tags** | Title: `og:title` → `twitter:title` → HTML `<title>`. Description: `og:description` → `twitter:description`. Image: `og:image` → `twitter:image`. URL: `og:url` → `rel=canonical` → request URL. |
| **Copy** | **Copy title** and **Copy URL**. Recents cap at 20. |
| **Empty** | No `og:` / `twitter:` title, description, or image → **No Open Graph or Twitter card tags.** HTML `<title>` still shows. |
| **Login** | Open at Login from Settings (`SMAppService`). |

---

## Download

| File | Use |
|---|---|
| **`CardPreview.app.zip`** | Unzip, drag **CardPreview** onto **Applications** |

**[Releases](https://github.com/BadryansahBangsawan/card-preview/releases/latest)**

---

## Install

### Zip

1. Download `CardPreview.app.zip` from [Releases](https://github.com/BadryansahBangsawan/card-preview/releases/latest).
2. Unzip. Drag **CardPreview** onto **Applications**.
3. First open (ad-hoc signed):

```bash
xattr -cr /Applications/CardPreview.app
open /Applications/CardPreview.app
```

Still blocked: System Settings → Privacy & Security → Open Anyway.

### Source

```bash
git clone https://github.com/BadryansahBangsawan/card-preview.git
cd card-preview
bash package-app.sh
ditto dist/CardPreview.app /Applications/CardPreview.app
xattr -cr /Applications/CardPreview.app
open /Applications/CardPreview.app
```

Do not run `dist/CardPreview.app` while `/Applications/CardPreview.app` is running (same bundle ID).

---

## How to open

This is an `LSUIElement` extra. Proof it is running is the **photo.on.rectangle** status item on the **right** of the menu bar, not a window from Finder or Launchpad.

1. Click that extra. The panel is opaque ~360×420 pt, not a 10px strip.
2. If the bar is full, look behind the Control Center overflow chevron **«**.
3. Double-clicking in Finder/Launchpad only changes the left-side app name. That is expected. There is no Dock icon.

---

## Usage

1. Click the extra.
2. Enter an `https://` URL and click **Fetch**.
3. Read title, description, image, and URL.
4. **Copy title** / **Copy URL**. Click a recent to prefill.
5. **Settings** at the bottom: Open at Login, Quit.

`https://ogp.me` → title **Open Graph protocol**, description, and `https://ogp.me/logo.png`.

`https://example.com` → **No Open Graph or Twitter card tags.** HTML title **Example Domain** still shows.

---

## Permissions

No TCC prompts. `Info.plist` sets `NSAllowsArbitraryLoads` so `http` hosts are reachable.

---

## Data

| What | Where |
|---|---|
| Recents | `~/Library/Application Support/Card Preview/recents.json` |
| Open at Login | `SMAppService.mainApp` (Settings toggle) |

A missing recents file is an empty list. A file that will not decode is an empty list plus a red banner. The extra does not crash.

---

## Privacy

Fetch uses an ephemeral `URLSession`. The URL you type leaves this Mac only as that HTTP request (HTML, then the image URL if one exists).

---

## Uninstall

Delete `/Applications/CardPreview.app`. Then:

```bash
rm -rf "$HOME/Library/Application Support/Card Preview"
```

Turn off **Card Preview** in System Settings → General → Login Items if it remains.

---

## Troubleshooting

| What you see | What to do |
|---|---|
| Finder “opens” nothing / no Dock icon | Click the **photo.on.rectangle** extra on the right of the menu bar. |
| Extra missing | Overflow **«**, or `pgrep -x CardPreview` then `open /Applications/CardPreview.app`. |
| “Damaged” / cannot verify | `xattr -cr /Applications/CardPreview.app`. `spctl --assess` is `rejected` even when it runs. |
| **URL must be http or https.** | Use an `http` or `https` URL. |
| **No Open Graph or Twitter card tags.** | The page has no `og:` / `twitter:` title, description, or image. |
| **HTML truncated to 1MB.** | Only the first megabyte was parsed. |
| Image URL as text, no picture | Image download or decode failed; the red label has the error. |
| ~10px empty strip under the bar | Reinstall from this repo. |

---

## Build from source

```bash
git clone https://github.com/BadryansahBangsawan/card-preview.git
cd card-preview
swift build -c release --product CardPreview
bash package-app.sh
open dist/CardPreview.app
```

Tag `v*` runs CI: `CardPreview.app.zip`. Never commit `dist/`.

Layout: `Sources/` (SwiftPM executable), `Info.plist`, `Assets/AppIcon.icns`, `package-app.sh`. `FunTheme.swift` is copied verbatim (no shared package).

---

## FAQ

**Why is there no Dock icon?**  
It is a menu extra. Click the photo.on.rectangle item on the **right** of the menu bar.

**Does this need Screen Recording?**  
No. It GETs HTML and the image URL.

**Where did the URL list go?**  
`~/Library/Application Support/Card Preview/recents.json` (20 URLs).

**How do I stop it opening at login?**  
Settings in the panel, or System Settings → General → Login Items → **Card Preview**.

---

<div align="center">

[MIT](LICENSE)

</div>
