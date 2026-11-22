# ChargeMotion

**Smart charging. Dynamic wallpapers. A better desktop experience.**

ChargeMotion is a desktop application that manages video wallpapers based on a laptop's charging status.

This repository contains separate platform-specific applications.

## Platform Status

| Platform | Technology | Status |
|---|---|---|
| Windows 10/11 (x64) | Tauri 2, Rust, JavaScript | Available for testing |
| macOS | Swift, SwiftUI | Under development |
| Linux | To be determined | Future consideration |

## Windows Features

- Automatic laptop charging-status detection.
- Video wallpaper selection and playback.
- Automatic wallpaper activation and restoration.
- Video library with video information and preview.
- Live charging and wallpaper status dashboard.
- Windows startup configuration.
- System tray controls.
- Modern dark interface with pastel-green accents.
- Reduced-motion and performance optimizations.

## How It Works

1. Launch ChargeMotion.
2. Select a video from your computer.
3. ChargeMotion monitors laptop power status.
4. The wallpaper is managed according to the charging condition.
5. When that condition ends, the previous desktop wallpaper is restored.

The current version supports one selected video at a time.

## Download

[Visit GitHub Releases](https://github.com/KushagraSinghBharadwaj/ChargeMotion/releases).

The macOS application is under development and is not yet available for download.

## Windows Development

### Requirements

- Windows 10 or Windows 11 (64-bit).
- Node.js and npm.
- Rust and Cargo.
- Microsoft C++ Build Tools.
- Microsoft Edge WebView2 Runtime.

See the [Tauri prerequisites](https://tauri.app/start/prerequisites/).

### Clone the repository

```powershell
git clone https://github.com/KushagraSinghBharadwaj/ChargeMotion.git
cd ChargeMotion\Windows
```

### Install dependencies

```powershell
npm install
```

### Run in development mode

```powershell
npm run tauri dev
```

### Build the frontend

```powershell
npm run build
```

### Build the Windows application

```powershell
npm run tauri build
```

## macOS Development

The macOS application is planned as a separate native Swift and SwiftUI application.

Building and testing require a Mac with Xcode. Its source code and build process will be maintained inside the `macOS/` directory.

## Project Structure

```text
ChargeMotion/
├── Windows/
│   ├── src/
│   ├── src-tauri/
│   ├── public/
│   ├── index.html
│   ├── wallpaper.html
│   └── package.json
├── macOS/
│   └── README.md
├── README.md
├── LICENSE
└── .gitignore
```

## Automatic Windows Startup

1. Open ChargeMotion.
2. Go to **Settings**.
3. Find the **Startup** setting.
4. Enable the startup toggle.

Disable the same setting to stop automatic launching.

## Contributing

Bug reports, suggestions and contributions are welcome. Please test changes on the relevant platform before submitting a pull request.

## Support

Email: **kushagra4204@gmail.com**

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).

## Creator

**Created by Kushagra Singh Bharadwaj.**