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
|                                 hyper + h   This cheat sheet     |
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
