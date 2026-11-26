-- Ableton Live 12 exposes the device selectors as named accessibility controls.
local M = {}
local bundle = "com.ableton.live"
local directions = {"Output", "Input"}
local deskDevice = {Input = "ES-9 + NT1", Output = "ES-9"}

-- Live appends channel counts, which change when the USB mic is unplugged.
local function deviceName(label)
    if label then return (label:gsub(" %(%d+ In, %d+ Out%)$", "")) end
end

local function deskSelection(direction, label)
    local name = deviceName(label)
    return name == deskDevice[direction] or (direction == "Input" and name == "ES-9")
end

function M.running()
    return hs.application.applicationsForBundleID(bundle)[1]
end

-- Snapshot each direction independently, without waking Live or opening Settings.
-- Bound disk reads even when Live's log has grown for months.
function M.snapshot()
    local app = M.running()
    if not app then return nil end
    local snap = {pid = app:pid()}
    local info = hs.application.infoForBundlePath(app:path())
    local version = info and (info.CFBundleShortVersionString or ""):match("^%d+%.%d+%.%d+")
    if not version then return snap end
    local path = os.getenv("HOME") .. "/Library/Preferences/Ableton/Live " .. version .. "/Log.txt"
    local file = io.open(path, "rb")
    if not file then return snap end
    local size = file:seek("end")
    file:seek("set", math.max(0, size - 1024 * 1024))
    for line in file:lines() do
        local direction, name = line:match("Audio In Out: (%a+) Device: ([^\r\n]+)$")
        if direction == "Input" or direction == "Output" then snap[direction] = name end
    end
    file:close()
    return snap
end

-- Restore only the directions previously assigned to ES-9. Hyper+U also
-- adopts No Device as the user's explicit desk setup. A different selection wins.
function M.intent(current, beforeSleep, manual)
    local wanted = {}
    if not current then return wanted end
    for _, d in ipairs(directions) do
        local old = beforeSleep and beforeSleep.pid == current.pid and beforeSleep[d]
        if deskSelection(d, current[d]) or
            ((current[d] == "No Device" or current[d] == nil) and (manual or deskSelection(d, old))) then
            wanted[d] = deskDevice[d]
        end
    end
    return wanted
end

function M.lost(current, beforeSleep)
    if not current or not beforeSleep or current.pid ~= beforeSleep.pid then return false end
    for _, d in ipairs(directions) do
        if current[d] == "No Device" and deskSelection(d, beforeSleep[d]) then return true end
    end
    return false
end

local function find(root, matches, depth)
    if not root then return end
    root:setTimeout(0.25)
    if matches(root) then return root end
    if depth > 0 then
        for _, child in ipairs(root.AXChildren or {}) do
            local hit = find(child, matches, depth - 1)
            if hit then return hit end
        end
    end
end

function M.restore(pid, wanted, sleep, cleanup)
    if not (wanted.Input or wanted.Output) then return false end
    local app = M.running()
    if not app or app:pid() ~= pid then return false end
    local root = hs.axuielement.applicationElement(app)
    root:setTimeout(0.3)
    local previous = hs.application.frontmostApplication()
    local function front()
        local current = hs.application.frontmostApplication()
        return current and current:pid() == pid
    end
    local function settings()
        for _, w in ipairs(root.AXWindows or {}) do
            if w.AXTitle == "Settings" or w.AXTitle == "Preferences" then return w end
        end
    end
    local function waitFor(what, fn)
        for _ = 1, 12 do
            local value = fn()
            if value then return value end
            sleep(0.15)
        end
        error("Live: couldn't find " .. what, 0)
    end
    local function click(el)
        if not front() then error("Live lost focus during audio recovery", 0) end
        for _, action in ipairs(el:actionNames() or {}) do
            if action == "AXPress" and el:performAction(action) then return end
        end
        local p, s = el.AXPosition, el.AXSize
        if not p or not s then error("Live control cannot be clicked", 0) end
        hs.eventtap.leftClick({x = p.x + s.w / 2, y = p.y + s.h / 2})
    end
    local alreadyOpen = settings() ~= nil
    local opened = false
    cleanup(function()
        if front() and opened and settings() then hs.eventtap.keyStroke({}, "escape", 0, app) end
        if previous and previous:pid() ~= pid and front() then previous:activate() end
    end)
    app:activate()
    waitFor("front window", front)
    if not alreadyOpen then
        hs.eventtap.keyStroke({"cmd"}, ",", 0, app)
        opened = true
    end
    local win = waitFor("Settings", settings)
    local function control(desc)
        return find(win, function(e) return e.AXDescription == desc end, 5)
    end
    if not control("Audio Output Device") then
        click(waitFor("Audio settings tab", function() return control("Audio") end))
    end
    local restored = false
    for _, d in ipairs(directions) do
        local target = wanted[d]
        if target then
            local label = "Audio " .. d .. " Device"
            local selector = waitFor(label, function() return control(label) end)
            local selected = deviceName(selector.AXValue)
            if selected == "No Device" or (d == "Input" and selected == "ES-9") then
                click(selector)
                local item = waitFor(target .. " in " .. label, function()
                    local popup = root.AXFocusedWindow
                    if not popup or (popup.AXTitle or "") ~= "" then return end
                    return find(popup, function(e)
                        return deviceName(e.AXTitle) == target or deviceName(e.AXDescription) == target
                    end, 4)
                end)
                click(item)
                waitFor(label .. " confirmation", function()
                    local el = control(label)
                    return el and deviceName(el.AXValue) == target
                end)
                restored = true
            end
        end
    end
    return restored
end

return M
