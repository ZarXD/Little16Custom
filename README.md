# Little16 Custom

**iPhone X gestures for iPhone 8/7/6S with full customization in Settings.**

Fork of [Little16](https://github.com/michaelmelita1/Little16) with a PreferenceLoader-based settings pane inspired by GestureXV.

## Features

- iPhone X fluid gestures (home, app switcher, Control Center)
- **Customizable Control Center position**: Top Right (status bar drag), Bottom Right, Bottom Left, or Disabled
- **Status bar style**: Legacy (original) or iPad
- **Floating dock style**: Legacy or iPad
  - Hide dock background
  - Enable/disable recent apps in dock
  - Remove App Library from dock
- **Quick Actions**: Flashlight & Camera buttons on lock screen
- **Appearance**: Rounded app switcher, rounded dock recents, home indicator toggle
- Respring button in settings

## Settings Location

**Settings → Little16**

All changes require a respring to apply (button included at the bottom of settings).

## Building

### GitHub Actions (recommended — works from any OS)

1. Push this folder to a GitHub repo
2. Actions tab → "Build DEB" → "Run workflow"
3. Download the `.deb` from the Artifacts section

### Local build (Linux / WSL / macOS)

```bash
# Install Theos first: https://github.com/theos/theos
git clone <your-repo-url>
cd Little16Custom
make package FINALPACKAGE=1
```

The `.deb` will be in `./packages/`.

## Installing

1. Copy the `.deb` to your device (AirDrop, scp, Sileo local install, etc.)
2. Open in Sileo/Filza → Install
3. Respring

Or use `dpkg -i com.michaelmelita1.little16_1.0.0_iphoneos-arm64.deb` in terminal.

## CC Position Notes

| Setting | Internal value | Behavior |
|---|---|---|
| **Top Right (Status Bar)** | 3 | Swipe down from top-right corner of the status bar. This matches real iPhone X behavior. Uses `presentingEdge=1` + `_defaultPresentationGesture=1` (proven working on iOS 15/16 via HomeGesture1315). |
| **Bottom Right Corner** | 1 | Swipe up from the bottom-right edge of the screen. |
| **Bottom Left Corner** | 2 | Swipe up from the bottom-left edge of the screen. |
| **Disabled** | 0 | CC grab gesture is disabled. |

**Note:** "Top Right" and "Bottom Right" both use the same underlying hook (`presentingEdge=1`) because on home-button devices with the home gesture enabled, this combo empirically enables both the bottom-right corner swipe AND the top-right status bar drag on iOS 15-16. If the status-bar drag doesn't work on your device, try switching to "Bottom Right Corner."

## Compatibility

- **Devices**: iPhone 6S, 7, 8, SE 2nd gen
- **iOS**: 15.0 - 16.x (possibly iOS 17+)
- **Jailbreak**: Dopamine (rootless), palera1n, XinaA15, etc.
- **Package manager**: Sileo, Zebra

## Credits

- **michaelmelita1** — original Little16
- **ryannair05** — [Little12](https://github.com/ryannair05/Little12) (settings architecture, dock/recents hooks)
- **ETHN** — [FloatingDockXVI](https://github.com/nahtedetihw/FloatingDockXVI) (dock background hide, recents/app library toggle, iOS 15/16 init variants)
- **Tweaker177** — [HomeGesture1315](https://github.com/Tweaker177/HomeGesture1315) (CC top-right behavior on iOS 15)
- **duraidabdul** — [Neptune](https://github.com/duraidabdul/Neptune) (CC grabber layout)
