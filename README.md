# ChargeMotion

**Smart charging. Dynamic wallpapers. A better desktop experience.**

ChargeMotion is a Windows desktop application that automatically manages your desktop video wallpaper based on your laptop's charging status.

Built with Tauri 2, Rust, JavaScript, HTML and CSS.

## Features

- Automatic laptop charging detection.
- Video wallpaper selection and playback.
- Automatic wallpaper activation and restoration.
- Video library with video information and preview.
- Live charging and wallpaper status dashboard.
- Windows startup configuration.
- System tray controls.
- Premium black and pastel-green interface.
- 3D-inspired interactions and animations.
- Reduced-motion and performance optimizations.

## How It Works

1. Launch ChargeMotion.
2. Select a video from your computer.
3. ChargeMotion monitors your laptop's power status.
4. The application manages wallpaper activation based on the charging condition.
5. When that condition ends, the previous desktop wallpaper is restored.

The current version supports one selected video at a time.

## Download

The Windows installer will be available from the Releases section of this GitHub repository.

## Start ChargeMotion automatically

You can make ChargeMotion launch automatically whenever you sign in to Windows.

1. Open ChargeMotion.
2. Go to **Settings**.
3. Find the **Startup** setting.
4. Enable the startup toggle.

That's it! ChargeMotion will launch automatically after you sign in to Windows, including after restarting your computer.

To stop automatic launching, simply disable the same toggle in Settings.

## Development Setup
Requirements:
- Node.js
- Rust
- Microsoft C++ Build Tools
- Microsoft Edge WebView2 Runtime

See https://tauri.app/start/prerequisites/

Install dependencies:

    npm install

Run the application:

    npm run tauri dev

Build the frontend:

    npm run build

Build the Windows application:

    npm run tauri build

## Technology Stack

- Tauri 2
- Rust
- JavaScript
- HTML5
- CSS3
- Vite
- Node.js and npm

## Project Structure

- src/ Ã¢â‚¬â€ Frontend application code and styles.
- src-tauri/ Ã¢â‚¬â€ Rust backend and Tauri configuration.
- public/ Ã¢â‚¬â€ Public application assets.
- index.html Ã¢â‚¬â€ Main application entry point.
- wallpaper.html Ã¢â‚¬â€ Wallpaper window entry point.

## Platform Support

- Windows 10/11: Current tested platform.
- macOS: Planned; requires Mac build and testing.
- Linux: Future consideration.

## Contributing

Bug reports, suggestions and contributions are welcome. Please test changes before submitting a pull request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Creator

**Made by Kushagra Singh Bharadwaj**
