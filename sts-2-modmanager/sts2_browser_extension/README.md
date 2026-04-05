# STS2 Mod Manager - Browser Extension

## Installation (Edge/Chrome)

1. Open Edge and go to `edge://extensions/`
2. Enable "Developer mode" (toggle in bottom right)
3. Click "Load unpacked"
4. Select the `browser-extension` folder from this project
5. The extension icon will appear in your toolbar

## How It Works

1. Open STS2 Mod Manager (this starts the local server on `localhost:8765`)
2. Visit Nexus Mods Slay the Spire 2 mod pages
3. Click the purple "Download to STS2 Manager" button on mod pages
4. The mod will be downloaded and installed automatically

## Troubleshooting

- **"Manager not running"**: Make sure STS2 Mod Manager is open
- **Button not appearing**: Refresh the page or wait a few seconds
- **Download fails**: Check that the manager is fully loaded before clicking

## Files

- `manifest.json` - Extension configuration
- `background.js` - Service worker for API calls
- `content.js` - Injected into Nexus Mods pages
- `popup.html/js` - Extension popup UI
- `icons/` - Extension icons (SVG format)