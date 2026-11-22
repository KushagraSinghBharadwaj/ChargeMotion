# Desktop Wallpaper Window Manager

## Responsibilities

- Creates one wallpaper window per connected display.
- Places windows below desktop icons.
- Ignores mouse events so desktop interaction remains available.
- Tracks display connection and configuration changes.
- Supports showing and hiding wallpaper windows.
- Releases player references when all windows are removed.

## Original wallpaper preservation

ChargeMotion uses overlay windows rather than replacing the
system desktop wallpaper image.

The original macOS wallpaper remains managed by macOS.
When ChargeMotion hides or removes its windows, the original
desktop wallpaper becomes visible automatically.

No wallpaper backup or restoration operation is required.

## Display lifecycle

When a display disconnects, its window and associated player
reference are removed.

When a display connects, the manager creates a window if a
player has been assigned to that display.

## Memory management

hideAll() detaches video layers, hides windows, clears window
references, clears display player references, and resets the
published active display list.

setVisible(false) only hides windows. It preserves their
players so playback can resume without rebuilding the windows.

## Validation

Actual desktop layering, Spaces behavior, display reconnection,
and sleep/wake behavior must be tested on macOS.