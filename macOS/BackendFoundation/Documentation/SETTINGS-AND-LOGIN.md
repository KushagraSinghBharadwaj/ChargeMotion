# Settings Persistence and Launch at Login

## AppSettingsStore

Persists the existing AppSettings model as JSON.

Default location:

~/Library/Application Support/ChargeMotion/settings.json

Public methods:

- load()
- save(_:)
- deleteStoredSettings()
- settingsFileURL()

The store is an actor so its asynchronous operations are serialized.

## LaunchAtLoginManager

Uses Apple's ServiceManagement framework and SMAppService.mainApp.

Public API:

- status
- isEnabled
- enable()
- disable()
- setEnabled(_:)

Launch at Login requires the application to be packaged and installed
as a proper macOS application. It cannot be meaningfully validated
by running the Swift package on Windows.

macOS may require the user to approve the login item in System Settings.

## Frontend integration

The SwiftUI frontend should:

1. Load settings when the application starts.
2. Retain the loaded AppSettings in its application state.
3. Save settings after user changes.
4. Read LaunchAtLoginManager.status to show the actual system state.
5. Handle registration errors and approval requirements.

Do not assume that requesting registration means the login item
has already been approved or enabled.

## Tests

AppSettingsStoreTests covers default settings, persistence round-trip,
and settings file creation.

All tests still require compilation and execution on macOS.
