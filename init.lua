-- =============================================================================
-- Hammerspoon Config — Nick's Setup
-- =============================================================================
-- Features:
--   1. Hyper key (Caps Lock via Karabiner) for app switching
--   2. Grid-based window management
--   3. Desktop mode / Laptop mode auto-switching
--   4. Clipboard-to-scratch-file hotkey
-- =============================================================================

-- Disable animations for snappy window moves
hs.window.animationDuration = 0

-- Where to log status messages
local log = hs.logger.new("init", "info")

-- =============================================================================
-- 1. HYPER KEY — App Switching
-- =============================================================================
-- Caps Lock is remapped to Cmd+Ctrl+Opt+Shift via Karabiner-Elements.
-- Tapping it alone sends Escape. Holding it + another key = hyper combo.
--
-- Adjust these app bindings to taste.

local hyper = {"cmd", "alt", "ctrl", "shift"}

-- Dismiss cheat sheet if visible (called by all other hyper bindings)
local cheatsheetAlert = nil
local function dismissCheatsheet()
  if cheatsheetAlert then
    hs.alert.closeSpecific(cheatsheetAlert)
    cheatsheetAlert = nil
  end
end

-- Direct app launchers: hyper + key -> focus or launch app
local appBindings = {
  t = "Ghostty",
  b = "Google Chrome",
  e = "Zed",
  s = "Slack",
  f = "Finder",
  y = "Heynote",
  l = "Linear",
}

for key, app in pairs(appBindings) do
  hs.hotkey.bind(hyper, key, function()
    dismissCheatsheet()
    local a = hs.application.get(app)
    if a then
      a:activate()
    else
      hs.application.launchOrFocus(app)
    end
  end)
end

-- Claude: use hs.application.open for reliable activation
hs.hotkey.bind(hyper, "c", function()
  dismissCheatsheet()
  hs.application.open("com.anthropic.claudefordesktop")
end)

-- Gmail: open in Chrome (or focus existing Gmail tab)
hs.hotkey.bind(hyper, "m", function()
  dismissCheatsheet()
  hs.urlevent.openURL("https://mail.google.com")
end)

-- =============================================================================
-- 2. GRID-BASED WINDOW MANAGEMENT
-- =============================================================================
-- Uses hs.grid for a flexible tiling system.
-- Hyper + G shows the interactive grid overlay.
-- Hyper + arrow keys / common positions for quick snapping.

hs.grid.setGrid("8x4")       -- 8 columns, 4 rows — 32 cells, all single-key hints
hs.grid.setMargins({0, 0})   -- no gaps between windows (set to {5, 5} for gaps)

-- Grid UI customization
hs.grid.ui.textSize = 60
hs.grid.ui.fontName = "Menlo"
hs.grid.ui.showExtraKeys = false  -- hide extra key labels in the grid

-- Custom grid hints: 4 rows x 8 columns = 32 cells
-- All single unmodified keys — no shift/ctrl needed, no ^ prefixes
hs.grid.HINTS = {
  {"a","s","d","f","j","k","l",";"},   -- home row
  {"q","w","e","r","u","i","o","p"},   -- top row
  {"z","x","c","v","n","m",",","."},   -- bottom row
  {"1","2","3","4","5","6","7","8"},   -- number row
}

-- Show the interactive grid (click to place windows)
hs.hotkey.bind(hyper, "g", function()
  dismissCheatsheet()
  hs.grid.show()
end)

-- Quick window positions using hyper + keys
local positions = {
  -- Halves
  left_half    = {x = 0, y = 0, w = 4, h = 4},
  right_half   = {x = 4, y = 0, w = 4, h = 4},
  top_half     = {x = 0, y = 0, w = 8, h = 2},
  bottom_half  = {x = 0, y = 2, w = 8, h = 2},
  -- Thirds
  left_third   = {x = 0, y = 0, w = 3, h = 4},
  mid_third    = {x = 3, y = 0, w = 3, h = 4},
  right_third  = {x = 5, y = 0, w = 3, h = 4},
  -- Two-thirds
  left_twothird  = {x = 0, y = 0, w = 5, h = 4},
  right_twothird = {x = 3, y = 0, w = 5, h = 4},
  -- Full screen (not macOS fullscreen, just fills the screen)
  full         = {x = 0, y = 0, w = 8, h = 4},
  -- Center (useful for reading/writing)
  center       = {x = 1, y = 0, w = 6, h = 4},
}

local function moveWindow(pos)
  return function()
    dismissCheatsheet()
    local win = hs.window.focusedWindow()
    if win then
      hs.grid.set(win, pos, win:screen())
    end
  end
end

-- Hyper + arrow keys for halves
hs.hotkey.bind(hyper, "left",  moveWindow(positions.left_half))
hs.hotkey.bind(hyper, "right", moveWindow(positions.right_half))
hs.hotkey.bind(hyper, "up",    moveWindow(positions.top_half))
hs.hotkey.bind(hyper, "down",  moveWindow(positions.bottom_half))

-- Hyper + number keys for thirds
hs.hotkey.bind(hyper, "1", moveWindow(positions.left_third))
hs.hotkey.bind(hyper, "2", moveWindow(positions.mid_third))
hs.hotkey.bind(hyper, "3", moveWindow(positions.right_third))

-- Hyper + return: toggle maximize (remembers original size/position)
local savedFrames = {}

-- Hyper + W: center window on screen without resizing
hs.hotkey.bind(hyper, "w", function()
  dismissCheatsheet()
  local win = hs.window.focusedWindow()
  if not win then return end
  local f = win:frame()
  local screen = win:screen():frame()
  f.x = screen.x + (screen.w - f.w) / 2
  f.y = screen.y + (screen.h - f.h) / 2
  win:setFrame(f)
end)

-- Hyper + return: toggle maximize (remembers original size/position)
hs.hotkey.bind(hyper, "return", function()
  dismissCheatsheet()
  local win = hs.window.focusedWindow()
  if not win then return end

  local id = win:id()
  local screen = win:screen()
  local screenFrame = screen:frame()
  local winFrame = win:frame()

  if savedFrames[id] then
    -- Restore original size and position
    win:setFrame(savedFrames[id])
    savedFrames[id] = nil
  else
    -- Save current frame, then maximize
    savedFrames[id] = winFrame
    win:setFrame(screenFrame)
  end
end)

hs.hotkey.bind(hyper, "[",      moveWindow(positions.left_twothird))
hs.hotkey.bind(hyper, "]",      moveWindow(positions.right_twothird))

-- Move window to next/previous screen (for multi-monitor)
hs.hotkey.bind(hyper, ".", function()
  dismissCheatsheet()
  local win = hs.window.focusedWindow()
  if win then win:moveToScreen(win:screen():next()) end
end)
hs.hotkey.bind(hyper, ",", function()
  dismissCheatsheet()
  local win = hs.window.focusedWindow()
  if win then win:moveToScreen(win:screen():previous()) end
end)

-- Make window larger / smaller by pixel increments (centered grow/shrink)
-- Hyper + = to grow, hyper + - to shrink
-- Each press adjusts by 40px on each side (80px total per axis)
local RESIZE_STEP = 40

hs.hotkey.bind(hyper, "=", function()
  dismissCheatsheet()
  local win = hs.window.focusedWindow()
  if not win then return end
  local f = win:frame()
  local screen = win:screen():frame()
  f.x = math.max(screen.x, f.x - RESIZE_STEP)
  f.y = math.max(screen.y, f.y - RESIZE_STEP)
  f.w = math.min(screen.w, f.w + RESIZE_STEP * 2)
  f.h = math.min(screen.h, f.h + RESIZE_STEP * 2)
  win:setFrame(f)
end)

hs.hotkey.bind(hyper, "-", function()
  dismissCheatsheet()
  local win = hs.window.focusedWindow()
  if not win then return end
  local f = win:frame()
  if f.w <= 200 or f.h <= 200 then return end  -- minimum size
  f.x = f.x + RESIZE_STEP
  f.y = f.y + RESIZE_STEP
  f.w = f.w - RESIZE_STEP * 2
  f.h = f.h - RESIZE_STEP * 2
  win:setFrame(f)
end)

-- =============================================================================
-- 3. CAFFEINE — Prevent sleep (cycle: off → 1 hour → 4 hours → indefinite)
-- =============================================================================
-- Hyper + A cycles through caffeine modes. Menubar icon shows current state.
-- All active modes use the strongest "system" caffeinate setting.
-- Timed modes (1h, 4h) auto-revert to off when the timer expires.

local caffeineModes = {"off", "1hour", "4hours", "indefinite"}
local caffeineModeIndex = 1  -- start at "off"
local caffeineTimer = nil    -- tracks the auto-off timer
local caffeineTickTimer = nil -- updates menubar countdown every minute
local caffeineExpiresAt = nil -- os.time() when the timed mode expires

-- Create menubar item
local caffeineMenubar = hs.menubar.new()

local caffeineDurations = {
  ["1hour"]  = 3600,   -- 1 hour in seconds
  ["4hours"] = 14400,  -- 4 hours in seconds
}

local function formatRemaining(seconds)
  if seconds < 0 then seconds = 0 end
  local h = math.floor(seconds / 3600)
  local m = math.floor((seconds % 3600) / 60)
  return string.format("%d:%02d", h, m)
end

local function updateCaffeineMenubar()
  if not caffeineMenubar then return end
  local mode = caffeineModes[caffeineModeIndex]

  local label
  if mode == "off" then
    label = "zzz"
    caffeineMenubar:setTitle(label)
  elseif caffeineExpiresAt then
    label = formatRemaining(caffeineExpiresAt - os.time())
    caffeineMenubar:setTitle(hs.styledtext.new(label, {
      color = {red = 1, green = 0, blue = 0},
    }))
  else
    label = "\xE2\x88\x9E"  -- ∞
    caffeineMenubar:setTitle(hs.styledtext.new(label, {
      color = {red = 1, green = 0, blue = 0},
    }))
  end

  caffeineMenubar:setTooltip("Caffeine: " .. mode)
  caffeineMenubar:setClickCallback(function()
    caffeineModeIndex = (caffeineModeIndex % #caffeineModes) + 1
    updateCaffeine()
  end)
end

local function updateCaffeine()
  local mode = caffeineModes[caffeineModeIndex]

  -- Cancel any existing timers
  if caffeineTimer then
    caffeineTimer:stop()
    caffeineTimer = nil
  end
  if caffeineTickTimer then
    caffeineTickTimer:stop()
    caffeineTickTimer = nil
  end
  caffeineExpiresAt = nil

  -- Clear all caffeinate assertions first
  hs.caffeinate.set("systemIdle", false)
  hs.caffeinate.set("displayIdle", false)
  hs.caffeinate.set("system", false)

  if mode ~= "off" then
    -- Prevent both system and display sleep
    hs.caffeinate.set("system", true)
    hs.caffeinate.set("displayIdle", true)

    -- Start auto-off timer and countdown ticker for timed modes
    local duration = caffeineDurations[mode]
    if duration then
      caffeineExpiresAt = os.time() + duration
      caffeineTimer = hs.timer.doAfter(duration, function()
        caffeineModeIndex = 1  -- back to "off"
        updateCaffeine()
        hs.notify.new({title = "Caffeine", informativeText = "Timer expired — sleep prevention off"}):send()
      end)
      caffeineTickTimer = hs.timer.doEvery(60, updateCaffeineMenubar)
    end
  end

  updateCaffeineMenubar()

  -- Brief alert on change
  local alertMessages = {
    off        = "Caffeine: OFF",
    ["1hour"]  = "Caffeine: ON — sleep paused for 1 hour",
    ["4hours"] = "Caffeine: ON — sleep paused for 4 hours",
    indefinite = "Caffeine: ON — sleep paused indefinitely",
  }
  hs.alert.show(alertMessages[mode], 1.5)
end

hs.hotkey.bind(hyper, "a", function()
  dismissCheatsheet()
  caffeineModeIndex = (caffeineModeIndex % #caffeineModes) + 1
  updateCaffeine()
end)

-- Initialize
updateCaffeine()

-- =============================================================================
-- DESKTOP MODE / LAPTOP MODE — Auto-detect external displays
-- =============================================================================
-- When you plug into your two Studio Displays, this applies a "desktop" layout.
-- When you unplug, it applies a "laptop" layout.
--
-- Since you have Stay installed, this is set up to COMPLEMENT Stay rather than
-- fight it. Stay handles restoring individual window positions; this handles
-- higher-level actions like launching/quitting apps, adjusting audio, etc.
--
-- Adjust the screen count and names to match your setup.

local STUDIO_DISPLAY_NAME = "Studio Display"  -- check via: hs.screen.allScreens()
local LAPTOP_SCREEN_NAME  = "Built-in Retina Display"

local function isDesktopMode()
  local screens = hs.screen.allScreens()
  -- Desktop mode = 3 screens (laptop + 2 Studio Displays)
  return #screens >= 3
end

local function onDesktopMode()
  log.i("Entering DESKTOP mode (external displays detected)")
  hs.notify.new({title = "Desktop Mode", informativeText = "Two Studio Displays connected"}):send()

  -- Example actions when docking:
  -- Set audio output to external speakers/display
  -- local device = hs.audiodevice.findOutputByName("Studio Display")
  -- if device then device:setDefaultOutputDevice() end

  -- Launch apps you only use at your desk
  -- hs.application.launchOrFocus("Mail")
end

local function onLaptopMode()
  log.i("Entering LAPTOP mode (built-in display only)")
  hs.notify.new({title = "Laptop Mode", informativeText = "Running on built-in display"}):send()

  -- Example actions when undocking:
  -- Switch audio to built-in speakers
  -- local device = hs.audiodevice.findOutputByName("MacBook Pro Speakers")
  -- if device then device:setDefaultOutputDevice() end
end

-- Track current mode to avoid re-triggering
local currentMode = isDesktopMode() and "desktop" or "laptop"

local screenWatcher = hs.screen.watcher.new(function()
  -- Small delay to let macOS finish configuring displays
  hs.timer.doAfter(2, function()
    local newMode = isDesktopMode() and "desktop" or "laptop"
    if newMode ~= currentMode then
      currentMode = newMode
      if newMode == "desktop" then
        onDesktopMode()
      else
        onLaptopMode()
      end
    end
  end)
end)
screenWatcher:start()

-- =============================================================================
-- 4. CLIPBOARD TO HEYNOTE
-- =============================================================================
-- Hyper + V appends the current clipboard contents to the Heynote
-- "Clipboard" buffer as a new text block with a timestamp.

local HEYNOTE_CLIPBOARD = os.getenv("HOME") ..
  "/Library/Application Support/Heynote/notes/clipboard.txt"

hs.hotkey.bind(hyper, "v", function()
  dismissCheatsheet()
  local clipboard = hs.pasteboard.getContents()
  if not clipboard or clipboard == "" then
    hs.notify.new({title = "Heynote", informativeText = "Clipboard is empty"}):send()
    return
  end

  local timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z")  -- UTC ISO 8601
  local block = string.format(
    "\n\xE2\x88\x9E\xE2\x88\x9E\xE2\x88\x9Etext-a;created=%s\n%s",
    timestamp, clipboard
  )

  local file = io.open(HEYNOTE_CLIPBOARD, "a")
  if file then
    file:write(block)
    file:close()
    hs.notify.new({title = "Heynote", informativeText = "Clipping added to Clipboard buffer"}):send()
  else
    hs.notify.new({title = "Heynote", informativeText = "Failed to write to Heynote"}):send()
  end
end)

-- =============================================================================
-- 5. CONFIG RELOAD
-- =============================================================================
-- Auto-reload when init.lua changes (so you get instant feedback while editing)

local configWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", function(files)
  local dominated = false
  for _, file in pairs(files) do
    if file:sub(-4) == ".lua" then
      dominated = true
    end
  end
  if dominated then
    hs.reload()
  end
end)
configWatcher:start()

-- Manual reload: hyper + R
hs.hotkey.bind(hyper, "r", function()
  dismissCheatsheet()
  hs.reload()
end)

-- =============================================================================
-- 6. SHORTCUT CHEAT SHEET OVERLAY
-- =============================================================================
-- Hyper + H shows an on-screen cheat sheet of all shortcuts.
-- Press hyper + h again (or any other hyper shortcut) to dismiss.

require("audio.recovery").start(hyper, dismissCheatsheet)

hs.hotkey.bind(hyper, "h", function()
  if cheatsheetAlert then
    hs.alert.closeSpecific(cheatsheetAlert)
    cheatsheetAlert = nil
  else
    local text = table.concat({
      "HYPER KEY SHORTCUTS  (Caps Lock = Hyper)",
      "",
      "APP SWITCHING                  WINDOW MANAGEMENT",
      "hyper + t   Terminal           hyper + g        Grid overlay",
      "hyper + b   Browser            hyper + arrows   Snap to half",
      "hyper + e   Editor             hyper + 1/2/3    Snap to thirds",
      "                               hyper + [  /  ]  Left/right 2/3",
      "hyper + s   Slack              hyper + return   Toggle maximize",
      "hyper + f   Finder             hyper + w        Center window",
      "hyper + c   Claude             hyper + .  /  ,  Next/prev screen",
      "hyper + l   Linear             hyper + =        Make larger",
      "hyper + m   Gmail              hyper + -        Make smaller",
      "",
      "CLIPBOARD                      OTHER",
      "hyper + v   Save to Heynote    hyper + a   Caffeine (off/1h/4h/∞)",
      "hyper + y   Open Heynote       hyper + r   Reload config",
      "hyper + u   Recover ES-9 audio hyper + h   This cheat sheet",
    }, "\n")

    hs.alert.defaultStyle.textFont = "Menlo"
    hs.alert.defaultStyle.textSize = 16
    hs.alert.defaultStyle.radius = 16
    hs.alert.defaultStyle.atScreenEdge = 0
    hs.alert.defaultStyle.fadeInDuration = 0.1
    hs.alert.defaultStyle.fadeOutDuration = 0.1
    hs.alert.defaultStyle.strokeColor = {white = 1, alpha = 0.2}
    hs.alert.defaultStyle.fillColor = {white = 0.1, alpha = 0.9}
    hs.alert.defaultStyle.textColor = {white = 1, alpha = 1}

    cheatsheetAlert = hs.alert.show(text, hs.alert.defaultStyle, hs.screen.mainScreen(), "indefinite")
  end
end)

hs.notify.new({title = "Hammerspoon", informativeText = "Config loaded"}):send()

-- =============================================================================
-- CHEAT SHEET (for reference)
-- =============================================================================
--[[
  HYPER KEY = Caps Lock (held) = Cmd+Ctrl+Opt+Shift

  APP SWITCHING:
    hyper + t  →  Terminal
    hyper + b  →  Safari
    hyper + x  →  Xcode
    hyper + e  →  Cursor
    hyper + s  →  Slack
    hyper + f  →  Finder
    hyper + m  →  Messages
    hyper + n  →  Notes
    hyper + p  →  Spotify
    hyper + z  →  Zoom

  WINDOW MANAGEMENT:
    hyper + g        →  Show grid overlay
    hyper + ←/→/↑/↓  →  Snap to half
    hyper + 1/2/3    →  Snap to thirds
    hyper + return   →  Maximize
    hyper + c        →  Center (2/3 width)
    hyper + [        →  Left 2/3
    hyper + ]        →  Right 2/3
    hyper + .        →  Move to next screen
    hyper + ,        →  Move to prev screen

  OTHER:
    hyper + v  →  Append clipboard to ~/Desktop/scratch.md
    hyper + r  →  Reload config
--]]
