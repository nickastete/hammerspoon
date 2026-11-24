# Hammerspoon Config

Personal [Hammerspoon](https://www.hammerspoon.org/) configuration for macOS automation. Uses a **Hyper key** (Caps Lock remapped to Cmd+Ctrl+Opt+Shift via [Karabiner-Elements](https://karabiner-elements.pqrs.org/)) as the modifier for all shortcuts.

## Features

### 1. App Switching
Instantly focus or launch apps with Hyper + key. Includes direct launchers for terminal, browser, editor, Slack, Finder, and more, plus a URL-based Gmail shortcut.

### 2. Grid-Based Window Management
An 8x4 grid system for flexible window tiling. Includes:
- **Interactive grid overlay** (Hyper+G) with single-key hints on home/top/bottom/number rows
- **Half/third/two-third snapping** via arrow keys and number keys
- **Toggle maximize** with original position memory
- **Center window** without resizing
- **Grow/shrink** windows symmetrically
- **Multi-monitor** window movement

### 3. Caffeine (Sleep Prevention)
Cycles through sleep prevention modes: off -> 1 hour -> 4 hours -> indefinite. Shows a menubar indicator with countdown timer for timed modes. Auto-reverts when timer expires.

### 4. Desktop/Laptop Mode Detection
Watches for display changes and auto-detects desktop mode (3+ screens with Studio Displays) vs laptop mode (built-in only). Sends notifications on mode switch. Designed to complement [Stay](https://cordlessdog.com/stay/) for window restoration.

### 5. Clipboard to Heynote
Hyper+V appends the current clipboard contents as a timestamped text block to a [Heynote](https://heynote.com/) clipboard buffer file.

### 6. Auto-Reload
Watches `~/.hammerspoon/` for `.lua` file changes and auto-reloads. Also available manually via Hyper+R.

### 7. Studio audio recovery (ES-9)

**Hyper+U** resets the connected Expert Sleepers ES-9 and reports the outcome.
Each system wake schedules a silent streaming check after three seconds. A healthy
or absent interface needs no notification. A second failed check triggers one
device-specific USB reset. The helper verifies a new USB registry ID and advancing
Core Audio output callbacks before reporting recovery. An error gets a notification.
The manual shortcut forces the reset even when a silent probe passes.

If Live 12 (English UI) is running, the integration reads its recent device
selections from the Live log and restores the input and output independently.
On wake, a pre-sleep snapshot also permits restoration of an ES-9 selection that
Live dropped during sleep. Another selected interface is preserved. Hyper+U can
assign ES-9 to a selector showing **No Device**. When settings need inspection,
Live can briefly come to the front. Locked sessions defer the operation until
unlock when Live is open. A closed Live stays closed. Transport and Live Sets
are never saved or changed by the recovery command.

Build the local helper once after cloning, and again after its source changes:

```sh
cd ~/.hammerspoon
make audio-helper
```

Requires macOS, the Xcode command line tools, and Hammerspoon's Accessibility
permission for Live. The helper runs locally as your user. Its system calls
have a six-second process deadline. To inspect a connected interface without
resetting it, run `audio/es9-helper id` and `audio/es9-helper probe` from this
directory. A successful probe exits 0, a missing interface 10, a stalled
stream 11, and an operational error 12. Run the policy tests with
`lua tests/audio-recovery.lua` (Lua 5.4+).

## Cheat Sheet (Hyper+H)

Pressing Hyper+H displays this overlay on screen:

```
+------------------------------------------------------------------+
|                                                                  |
|  HYPER KEY SHORTCUTS  (Caps Lock = Hyper)                        |
|                                                                  |
|  APP SWITCHING                  WINDOW MANAGEMENT                |
|  hyper + t   Terminal           hyper + g        Grid overlay    |
|  hyper + b   Browser            hyper + arrows   Snap to half    |
|  hyper + e   Editor             hyper + 1/2/3    Snap to thirds  |
|                                 hyper + [  /  ]  Left/right 2/3  |
|  hyper + s   Slack              hyper + return   Toggle maximize |
|  hyper + f   Finder             hyper + w        Center window   |
|  hyper + c   Claude             hyper + .  /  ,  Next/prev screen|
|  hyper + l   Linear             hyper + =        Make larger     |
|  hyper + m   Gmail              hyper + -        Make smaller    |
|                                                                  |
|  CLIPBOARD                      OTHER                            |
|  hyper + v   Save to Heynote    hyper + a   Caffeine (off/1h/4h)|
|  hyper + y   Open Heynote       hyper + r   Reload config       |
|  hyper + u   Recover ES-9 audio  hyper + h   This cheat sheet     |
|                                                                  |
+------------------------------------------------------------------+
```

## Prerequisites

- [Hammerspoon](https://www.hammerspoon.org/)
- [Karabiner-Elements](https://karabiner-elements.pqrs.org/) — remap Caps Lock to Hyper (Cmd+Ctrl+Opt+Shift)
- [Heynote](https://heynote.com/) (optional, for clipboard feature)

## Installation

```sh
git clone git@github.com:<your-username>/hammerspoon.git ~/.hammerspoon
```
