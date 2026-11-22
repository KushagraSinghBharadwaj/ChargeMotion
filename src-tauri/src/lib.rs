
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::fs;
use std::path::PathBuf;
use std::time::Duration;
use tauri::menu::{Menu, MenuItem};
use tauri::tray::TrayIconBuilder;
use tauri::{AppHandle, Emitter, Manager, WindowEvent};

fn settings_file(app: &AppHandle) -> Result<PathBuf, String> {
    let config_dir = app
        .path()
        .app_config_dir()
        .map_err(|e| format!("Could not locate settings directory: {e}"))?;

    fs::create_dir_all(&config_dir)
        .map_err(|e| format!("Could not create settings directory: {e}"))?;

    Ok(config_dir.join("settings.json"))
}

fn authorize_video(app: &AppHandle, path: &str) -> Result<(), String> {
    let metadata = fs::metadata(path)
        .map_err(|e| format!("Could not access video: {e}"))?;

    if !metadata.is_file() {
        return Err("The selected path is not a file.".into());
    }

    app.asset_protocol_scope()
        .allow_file(path)
        .map_err(|e| format!("Could not authorize video: {e}"))?;

    Ok(())
}

#[tauri::command]
fn save_selected_video(app: AppHandle, path: String) -> Result<(), String> {
    authorize_video(&app, &path)?;

    let file = settings_file(&app)?;
    let settings = json!({ "selected_video": path });

    fs::write(
        file,
        serde_json::to_string_pretty(&settings)
            .map_err(|e| e.to_string())?,
    )
    .map_err(|e| format!("Could not save video selection: {e}"))?;

    Ok(())
}

#[tauri::command]
fn get_selected_video(app: AppHandle) -> Result<Option<String>, String> {
    let file = settings_file(&app)?;

    if !file.exists() {
        return Ok(None);
    }

    let contents = fs::read_to_string(file)
        .map_err(|e| format!("Could not read settings: {e}"))?;

    let settings: Value = serde_json::from_str(&contents)
        .map_err(|e| format!("Invalid settings: {e}"))?;

    let Some(path) = settings["selected_video"].as_str() else {
        return Ok(None);
    };

    if !PathBuf::from(path).is_file() {
        return Ok(None);
    }

    authorize_video(&app, path)?;

    Ok(Some(path.to_string()))
}

#[tauri::command]
fn clear_selected_video(app: AppHandle) -> Result<(), String> {
    let file = settings_file(&app)?;

    if file.exists() {
        fs::remove_file(file)
            .map_err(|e| format!("Could not clear saved video: {e}"))?;
    }

    Ok(())
}

#[derive(Clone, Serialize, Deserialize)]
struct PowerStatus {
    on_ac_power: Option<bool>,
    battery_percent: Option<u8>,
}

#[cfg(target_os = "windows")]
fn read_power_status() -> Result<PowerStatus, String> {
    use windows_sys::Win32::System::Power::{
        GetSystemPowerStatus,
        SYSTEM_POWER_STATUS,
    };

    let mut native_status: SYSTEM_POWER_STATUS =
        unsafe { std::mem::zeroed() };

    let success = unsafe {
        GetSystemPowerStatus(&mut native_status)
    };

    if success == 0 {
        return Err("Windows could not retrieve power status.".into());
    }

    let on_ac_power = match native_status.ACLineStatus {
        0 => Some(false),
        1 => Some(true),
        _ => None,
    };

    let battery_percent =
        if native_status.BatteryLifePercent <= 100 {
            Some(native_status.BatteryLifePercent)
        } else {
            None
        };

    Ok(PowerStatus {
        on_ac_power,
        battery_percent,
    })
}

#[cfg(not(target_os = "windows"))]
fn read_power_status() -> Result<PowerStatus, String> {
    Err(
        "Native power monitoring is not implemented for this operating system yet."
            .into(),
    )
}

#[tauri::command]
fn get_power_status() -> Result<PowerStatus, String> {
    read_power_status()
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_autostart::init(
            tauri_plugin_autostart::MacosLauncher::LaunchAgent,
            Some(vec!["--from-autostart"]),
        ))
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_wallpaper::init())
        .setup(|app| {
            if cfg!(debug_assertions) {
                app.handle().plugin(
                    tauri_plugin_log::Builder::default()
                        .level(log::LevelFilter::Info)
                        .build(),
                )?;
            }

            // Show the dashboard for normal launches, but keep
            // Windows sign-in launches hidden in the system tray.
            let from_autostart = std::env::args()
                .any(|arg| arg == "--from-autostart");

            if !from_autostart {
                if let Some(window) = app.get_webview_window("main") {
                    window.show()?;
                }
            }

            // Create the system-tray menu.
            let open_item = MenuItem::with_id(
                app,
                "open",
                "Open ChargeMotion",
                true,
                None::<&str>,
            )?;

            let quit_item = MenuItem::with_id(
                app,
                "quit",
                "Quit ChargeMotion",
                true,
                None::<&str>,
            )?;

            let menu = Menu::with_items(
                app,
                &[&open_item, &quit_item],
            )?;

            let icon = app.default_window_icon()
                .expect("ChargeMotion default window icon is missing")
                .clone();

            let tray = TrayIconBuilder::new()
                .icon(icon)
                .menu(&menu)
                .tooltip("ChargeMotion")
                .on_menu_event(|app, event| {
                    match event.id.as_ref() {
                        "open" => {
                            if let Some(window) = app.get_webview_window("main") {
                                let _ = window.show();
                                let _ = window.unminimize();
                                let _ = window.set_focus();
                            }
                        }
                        "quit" => {
                            app.exit(0);
                        }
                        _ => {}
                    }
                })
                .build(app)?;

            // Keep a reference alive for the lifetime of the app.
            app.manage(tray);

            #[cfg(target_os = "windows")]
            {
                let app_handle = app.handle().clone();

                std::thread::spawn(move || {
                    let mut last_status: Option<Option<bool>> = None;

                    loop {
                        match read_power_status() {
                            Ok(status) => {
                                if last_status != Some(status.on_ac_power) {
                                    if let Err(error) = app_handle.emit(
                                        "power-status-changed",
                                        status.clone(),
                                    ) {
                                        log::warn!(
                                            "Could not emit power event: {error}"
                                        );
                                    }

                                    last_status = Some(status.on_ac_power);
                                }
                            }
                            Err(error) => {
                                log::error!(
                                    "Power detection failed: {error}"
                                );
                            }
                        }

                        std::thread::sleep(Duration::from_millis(250));
                    }
                });
            }

            Ok(())
        })
        .on_window_event(|window, event| {
            if window.label() == "main" {
                if let WindowEvent::CloseRequested { api, .. } = event {
                    // Closing the dashboard hides it instead of exiting.
                    api.prevent_close();

                    if let Err(error) = window.hide() {
                        log::warn!(
                            "Could not hide ChargeMotion dashboard: {error}"
                        );
                    }
                }
            }
        })
        .invoke_handler(tauri::generate_handler![
            save_selected_video,
            get_selected_video,
            clear_selected_video,
            get_power_status
        ])
        .run(tauri::generate_context!())
        .expect("error while building tauri application");
}