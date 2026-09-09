---
outline: false
---

# Install

Pack herdr-bar as a menu-bar extra and point it at Herdr already running on this Mac.

## Prerequisites {#prerequisites}

- **macOS 13+**
- **Swift** (Xcode or Command Line Tools)
- **Herdr 0.8+**, with at least one session up (`herdr` or `herdr session attach <name>`)
- A Herdr socket on disk:
  - default: `~/.config/herdr/herdr.sock`
  - named: `~/.config/herdr/sessions/<name>/herdr.sock`

::: tip Herdr has to be online first
herdr-bar does not start Herdr. A lone 22pt grey dot usually means the socket is missing, not that install failed.
:::

## Install {#steps}

Push a `v*` tag and `.github/workflows/release.yml` builds a universal `HerdrBar.app`, zips it, and attaches the zip to a GitHub Release. The binary is ad-hoc signed only — no Developer ID, no notarization, and no Sparkle updater (that lane needs Apple certificates this repo does not have). Gear → About can check GitHub Releases and open the latest tag; it cannot replace the running extra. After unzip:

```bash
xattr -cr HerdrBar.app
open HerdrBar.app
```

First launch may need right-click → Open.

Or build from source into `~/Applications/HerdrBar.app`:

```bash
git clone https://github.com/openalon-org/herdr-bar.git
cd herdr-bar
./scripts/install.sh
open ~/Applications/HerdrBar.app
```

`install.sh` calls `scripts/package-app.sh` (host-native, not universal):

1. `swift build -c release --product MacBar`
2. Write `~/Applications/HerdrBar.app` (`LSUIElement`, bundle id `dev.herdr.herdr-bar`)
3. Copy the binary to `Contents/MacOS/MacBar` and ad-hoc `codesign`

The app stays out of the Dock. The right side of the menu bar shows a dot (all idle / offline) or a cluster of status chips.

`install.sh` does not kill a running `MacBar`. After a source change, swap the live extra with `./scripts/reload.sh` (tests first, then install and restart).

## First launch {#first-run}

1. Open the Herdr TUI (default or a named session).
2. Open `HerdrBar.app`.
3. Left-click the menu-bar counts → dashboard.
4. Option-click → focus the highest-priority agent.
5. Right-click → refresh now.

::: warning Login items
macOS will not launch this at login by itself. Add `HerdrBar` under **System Settings → General → Login Items** if you want that.
:::

## Demo mode {#demo}

You can film the UI without Herdr. The fixture speaks newline JSON-RPC on `/tmp/herdr-demo.sock` and cycles a few status scenes:

```bash
./scripts/dev-run.sh --demo
```

`HERDR_SOCKET` pins a single socket. Discovery names it `demo` and skips `~/.config/herdr`.

```bash
HERDR_SOCKET=/path/to/herdr.sock ./scripts/dev-run.sh
```

Throwaway run without packing an app bundle:

```bash
./scripts/dev-run.sh
```
