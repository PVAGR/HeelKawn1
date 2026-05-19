# HeelKawn — Mobile playtest (Android)

## Download

1. On your phone, open **https://pvabazaar.org/#/download-app**
2. Tap **Download HeelKawn APK** (served from pvabazaar.org after site deploy, or GitHub release as fallback).
3. Install the APK (allow unknown sources for your browser if prompted).

Direct APK (GitHub):  
https://github.com/PVAGR/HeelKawn1/releases/download/android-latest/HeelKawn-android.apk

## In-game (mobile)

- Pinch zoom, drag to pan
- Bottom **MobileControls** bar: speed, zoom, build, inventory, menu
- Tap tiles to select / command (same as desktop left-click)

## Build a new APK

```powershell
# Local (Windows): run setup-android.ps1 once, then in Godot: Export → Android
# CI: push to main or run "Build Android APK" workflow on GitHub
```

Package: `org.pvagr.heelkawn`

## Site deploy

When `pva-bazaar-app` frontend deploys, CI copies the latest `android-latest` release APK into  
`Frontend/public/downloads/HeelKawn-android.apk` so phones can install from **pvabazaar.org**.
