# App Store Packaging Guide — Gikundiro Admin PWA

Guides for distributing the PWA via native app stores using PWABuilder and TWA.

---

## 1. Google Play Store via TWA (Trusted Web Activity)

### Prerequisites
- Google Play Developer account ($25 one-time fee)
- Android Studio installed
- Asset links verification (`/.well-known/assetlinks.json`)

### Steps

1. **Generate TWA project**
   ```bash
   # Using Bubblewrap CLI
   npx @nicolo-ribaudo/bubblewrap init --manifest https://admin.gikundiro.com/manifest.webmanifest
   ```

2. **Configure `twa-manifest.json`**
   ```json
   {
     "packageId": "com.gikundiro.admin",
     "host": "admin.gikundiro.com",
     "name": "Gikundiro Admin",
     "launcherName": "Gikundiro Admin",
     "startUrl": "/admin",
     "iconUrl": "https://admin.gikundiro.com/brand-mark.svg",
     "maskableIconUrl": "https://admin.gikundiro.com/brand-mark.svg",
     "themeColor": "#0038a8",
     "backgroundColor": "#07162f",
     "enableNotifications": true,
     "display": "standalone",
     "orientation": "portrait",
     "shortcuts": [
       { "name": "Dashboard", "url": "/admin" },
       { "name": "Matches", "url": "/admin/matches" }
     ]
   }
   ```

3. **Set up Digital Asset Links**
   Add to `public/.well-known/assetlinks.json`:
   ```json
   [{
     "relation": ["delegate_permission/common.handle_all_urls"],
     "target": {
       "namespace": "android_app",
       "package_name": "com.gikundiro.admin",
       "sha256_cert_fingerprints": ["YOUR_SHA256_FINGERPRINT"]
     }
   }]
   ```

4. **Build and sign APK**
   ```bash
   npx @nicolo-ribaudo/bubblewrap build
   ```

5. **Upload to Play Console** → Internal testing → Production

### Verification
- App opens in TWA (no browser chrome)
- Push notifications work
- Offline fallback renders

---

## 2. Microsoft Store via PWABuilder

### Steps

1. **Visit** [PWABuilder.com](https://www.pwabuilder.com)
2. **Enter URL**: `https://admin.gikundiro.com`
3. **Review audit results** (should score highly)
4. **Click "Package for stores"** → Select "Windows"
5. **Configure package**:
   - Package ID: `IKANISA.GikundiroAdmin`
   - Publisher display name: `IKANISA Ltd`
   - Version: `1.0.0`
6. **Download MSIX package**
7. **Submit to Microsoft Partner Center**

### Requirements
- Microsoft Partner Center account ($19 one-time fee for individuals)
- MSIX signing certificate

---

## 3. iOS App Store via PWABuilder

### Important Caveats
- iOS App Store PWAs run in a WKWebView wrapper
- Push notifications are supported since iOS 16.4
- No Background Sync, no Periodic Background Sync
- Service Worker scope is limited

### Steps

1. **Visit** [PWABuilder.com](https://www.pwabuilder.com)
2. **Enter URL**: `https://admin.gikundiro.com`
3. **Click "Package for stores"** → Select "iOS"
4. **Configure**:
   - Bundle ID: `com.gikundiro.admin`
   - App Name: `Gikundiro Admin`
   - Version: `1.0.0`
5. **Download Xcode project**
6. **Open in Xcode, sign with Apple Developer certificate**
7. **Archive → Upload to App Store Connect**

### Requirements
- Apple Developer account ($99/year)
- Xcode on macOS
- App Store review compliance

---

## 4. Cloudflare-Specific Considerations

- Digital Asset Links file must be served from the worker
- Add `/.well-known/assetlinks.json` as a static file in `public/`
- Ensure `wrangler.jsonc` routes don't block `/.well-known/` paths
- Test TWA with `adb` before store submission

---

## Timeline Recommendation

| Store | Effort | Priority |
|:--|:--:|:--:|
| Google Play (TWA) | 2 hours | P2 — largest mobile audience |
| Microsoft Store | 1 hour | P3 — low effort via PWABuilder |
| iOS App Store | 3 hours | P4 — iOS Safari A2HS already works |
