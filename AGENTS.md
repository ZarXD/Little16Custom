# AGENTS.md — Little16Custom

Project guidance for AI agents working on this repository.

## What this is
A theos tweak ("Little16 Custom") that brings iPhone X / iPad gestures and UI to
home-button iPhones. Target device: **iPhone 10,5 (8 Plus), iOS 16.7.16 (20H392),
Dopamine2-roothide jailbreak, arm64e**.

Gestures/features work. The settings pane opens, scrolls, and saves. Today's
status-bar work is an "iPhone X split" view-layout style (see Status Bar below).

## Repo layout
- `Tweak.xm` — all runtime hooks (groups: Core, StatusBarPad/RoundedPad/Modern,
  DockiPad, DockPlatter, RoundedRecents, RoundedSwitcher, ControlCenter*, QuickActions,
  Diagnostics). Logging via `L16DBG`.
- `Little16.plist` — filter: `com.apple.springboard` **only**. Do NOT add
  `com.apple.Preferences`; injecting Settings broke the pane (UIWindow hooks).
- `Little16Prefs/` — Settings bundle (RootListController.m + Resources/Root.plist).
- `layout/Library/PreferenceBundles/Little16Prefs.bundle/` — bundle shipped to userland.
- `.github/workflows/build.yml` — CI: builds rootless + roothide (arm64 + arm64e),
  auto-fetches Procursus ldid, publishes both debs to the single GitHub Release
  `v1.0.0` (assets overwritten every push).

## Build → device loop (do not skip steps)
1. Edit, `git commit`, `git push origin master`.
2. Wait for the latest Actions run; verify `conclusion == "success"`.
3. `gh release download v1.0.0 -R ZarXD/Little16Custom -p com.michaelmelita1.little16_1.0.0_iphoneos-arm64e.deb -D <tmp> --clobber`
   (pattern must be the exact filename — `*.arm64e.deb` matches nothing).
4. `scp` the deb to `mobile@192.168.0.12:/tmp/l16.deb`.
5. `ssh` install: `echo 'vee' | /var/jb/usr/bin/sudo -S /var/jb/usr/bin/dpkg -i /tmp/l16.deb`
6. User resprings; tweak runs in SpringBoard.

## Device / SSH quirks
- SSH: `mobile@192.168.0.12`, password `vee` (root/sudo same). Use
  `SSH_ASKPASS=<opencode temp>\askpass.exe` + `SSH_ASKPASS_REQUIRE=force`.
- **Remote zsh quoting**: ssh.exe strips double quotes. Wrap remote command in a
  PowerShell double-quoted string, keep inner tokens single-quoted. Avoid glob
  patterns at arg start (`zsh: no matches found`).
- **roothide paths**: real system/data lives under `/rootfs/` (e.g.
  `/rootfs/private/var/mobile`). `/var/jb` is the jbroot. Searches under
  `/private/var/mobile` or `/tmp` mislead.
- **Respring truth**: `killall -9 SpringBoard`, `ldrestart`, `sbreload` do NOT
  restart Services/SpringBoard on this device. Only `launchctl reboot userspace`
  works (SSH drops mid-run — expected).
- Crash logs: exist, at `/rootfs/private/var/mobile/Library/Logs/CrashReporter/`
  (e.g. `Preferences-*.ips`). The "CrashReporter disabled" assumption was wrong.
- Device tools: `defaults read`, `dpkg-deb`, `ldid` (2.1.5-procursus7), `grep -a`,
  `find`, `dd` (coreutils 9.3) exist. **No** curl/wget/python3/strings/ps.
  `plutil -p` is broken; use `defaults read com.michaelmelita1.little16` for live prefs.
- L16DBG logs land at `/rootfs/private/var/tmp/little16tweak.log` (/tmp) and
  `/rootfs/private/var/mobile/little16tweak.log` (NSHomeDirectory).

## .roothidepatch symlink — CRITICAL
The worktree intentionally lacks `layout/Library/PreferenceBundles/Little16Prefs.bundle/Little16Prefs.roothidepatch`
(it exists on device). It is tracked in git only via the index cacheinfo entry
(blob `06d69eed1f50eb288e096141c70a1ff159abf494`, mode 120000 → target
`/usr/lib/DynamicPatches/AutoPatches.dylib`).

ANY `git add -A` stages its deletion. After EVERY commit, run:
```
git update-index --cacheinfo 120000,06d69eed1f50eb288e096141c70a1ff159abf494,layout/Library/PreferenceBundles/Little16Prefs.bundle/Little16Prefs.roothidepatch
```
Then push.

## Config plumbing (do not regress)
- Preferences domain: `com.michaelmelita1.little16` (settings app) == kPrefsID (tweak).
- The tweak must read prefs from the LIVE cfprefsd store, not a plist file:
  `CFPreferencesAppSynchronize` + per-key `CFPreferencesCopyAppValue` in
  `loadPreferences` (`PrefValue`). Reading the `.plist` FILE gave stale/incomplete
  values (only 4 of 11 keys) → "toggles had no effect".
- Pane posts Darwin notification `com.michaelmelita1.little16/prefsUpdated`;
  the tweak registers a CFNotification observer that re-runs `loadPreferences`.

## RootListController.m crash history
iOS 16 PSListController scroll crash (Settings force-closed while scrolling):
`objc_retainAutoreleaseReturnValue ←
-PSListControllerDefaultAppearanceProvider estimatedHeightOfRowForCellWithIndexPath
← ...unprotectedSpecifiers`. Cause: `_specifiers = [load specifiers]` was stored
without retain → use-after-free across runloop turns. **Fix: `.retain`ed array**
(`_specifiers = [[self loadSpecifiersFromPlistName:@"Root" target:self] retain];`).
Do not revert.

## Status bar facts (verified on-device, iOS 16.7.16)
- Only these providers exist at runtime: `_UIStatusBarVisualProvider_Pad_ForcedCellular`,
  `_UIStatusBarVisualProvider_RoundedPad_ForcedCellular`.
- `_UIStatusBarVisualProvider_Split58` / `_Split61` are GONE on iOS 16 (Apple removed
  them). Swapping to them is a no-op (guard falls back to `%orig`). LittleXS/Poseidon/
  HalFiPad/GestureXV techniques are iOS 13–15.
- GestureXV "iPhone X status bar" on iOS 16 triggers the red `rdar:45025538` bar —
  an Apple resolution-mismatch warning; do not reproduce.
- "iPhone X" style (statusBarStyle==2) = WHITE text split layout emulated via
  `_UIStatusBar layoutSubviews` view-layout hook: time stays on the LEFT;
  cellular/wifi/battery item views are pushed to the RIGHT group.
  No resolution change, no red bar. (Class names: `_UIStatusBarBatteryView`,
  `_UIStatusBarWifiSignalView`, `_UIStatusBarCellularSignalView`.)
- statusBarStyle: `0=Legacy, 1=iPad, 2=iPhone X, 3=Rounded iPad`.

## Misc conventions
- Keep the user-visible UI in Indonesian (user is Indonesian-speaking).
- Rounding options are radius SLIDERS (key `roundedAppSwitcher`/`roundedDockRecents`,
  float 0–30, 0=off), not switches. Tweak reads them as float; legacy bool 1 → 14.0.
- `%init` decisions live in `%ctor`; groups must be mutually exclusive per setting.
- Do not add new dependency frameworks without checking the device can load them.