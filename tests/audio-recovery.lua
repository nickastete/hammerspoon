-- Exercise the same hotkey and watcher callbacks as Hammerspoon with a virtual
-- clock. No process, notification, USB device or Ableton instance is touched.
local realLive = require("audio.live")
local function scenario(name, options)
    local queue, commands, notices, repairs = {}, {}, {}, {}
    local manual, power
    local wake = {systemWillSleep = 1, systemDidWake = 2, screensDidUnlock = 3}
    local function enqueue(fn)
        local item = {run = fn}
        function item:stop() self.cancelled = true end
        table.insert(queue, item)
        return item
    end
    function wake.new(fn)
        power = fn
        return {start = function(self) return self end}
    end
    local id = "old"
    local probes = {table.unpack(options.probes or {0})}
    local current = options.before
    local locked = options.locked
    hs = {
        configdir = "/mock", logger = {new = function() return {e = function() end, i = function() end} end},
        timer = {doAfter = function(_, fn) return enqueue(fn) end},
        hotkey = {bind = function(_, _, fn) manual = fn end},
        caffeinate = {watcher = wake, sessionProperties = function() return {CGSSessionScreenIsLocked = locked} end},
        notify = {new = function(n) return {send = function() table.insert(notices, n.informativeText) end} end},
        task = {new = function(_, cb, args)
            local op = args[1]
            table.insert(commands, op)
            return {start = function()
                enqueue(function()
                    if op == "id" then cb(options.absent and 10 or 0, id, "")
                    elseif op == "probe" then cb(assert(table.remove(probes, 1)), "", "")
                    elseif op == "reset" then
                        assert(args[2] == id)
                        id = "new"; cb(options.resetError and 12 or 0, "", options.resetError or "")
                    else error(op) end
                end)
                return true
            end}
        end}
    }
    package.loaded["audio.live"] = {
        snapshot = function() return current end, intent = realLive.intent, lost = realLive.lost,
        restore = function(pid, wanted)
            table.insert(repairs, {pid = pid, wanted = wanted})
            if options.restoreError then error(options.restoreError, 0) end
            return wanted.Input or wanted.Output
        end
    }
    local recovery = dofile("audio/recovery.lua")
    recovery.start({}, function() end)
    local function drain()
        local iterations = 0
        while #queue > 0 do
            iterations = iterations + 1; assert(iterations < 100)
            local item = table.remove(queue, 1)
            if not item.cancelled then item.run() end
        end
    end
    if options.manual then manual() else
        power(wake.systemWillSleep)
        current = options.after or current
        power(wake.systemDidWake)
        power(wake.systemDidWake) -- duplicate wake delivery coalesces
    end
    drain()
    if locked then
        assert(#notices == 0 and #repairs == 0)
        locked = false
        power(wake.screensDidUnlock)
        drain()
    end
    assert(table.concat(commands, ",") == options.commands, name .. ": " .. table.concat(commands, ","))
    assert(#notices == (options.notice and 1 or 0) and notices[1] == options.notice,
           name .. ": " .. table.concat(notices, ","))
    assert(#repairs == (options.want and 1 or 0), name .. ": restore count")
    if options.want then
        for _, dir in ipairs({"Input", "Output"}) do
            assert((repairs[1].wanted[dir] or false) == options.want[dir], name .. ": " .. dir)
        end
    end
    print("ok - " .. name)
end

local es9 = "ES-9 (16 In, 16 Out)"
local aggregate = "ES-9 + NT1"
local desk = {pid = 42, Input = aggregate .. " (17 In, 16 Out)", Output = es9}
local noMic = {pid = 42, Input = aggregate .. " (16 In, 16 Out)", Output = es9}
local mixed = {pid = 42, Input = "USB Microphone", Output = es9}
local dropped = {pid = 42, Input = "USB Microphone", Output = "No Device"}
local outputOnly = {Input = false, Output = "ES-9"}
local both = {Input = aggregate, Output = "ES-9"}
scenario("wake away from desk", {absent = true, commands = "id"})
scenario("manual away from desk", {manual = true, absent = true, commands = "id", notice = "ES-9 is disconnected."})
scenario("healthy wake", {before = desk, commands = "id,probe"})
scenario("mic unplugged during sleep", {before = desk, after = noMic, commands = "id,probe"})
for _, state in ipairs({desk, noMic}) do
    scenario("dropped aggregate input after " .. state.Input, {before = state,
        after = {pid = 42, Input = "No Device", Output = es9}, commands = "id,probe",
        notice = "Audio restored.", want = both})
end
scenario("manual recovery from missing devices", {manual = true,
    before = {pid = 42, Input = "No Device", Output = "No Device"}, probes = {0,0},
    commands = "id,probe,reset,id,probe", notice = "ES-9 reset. Audio streaming verified.", want = both})
scenario("Live timeout after successful manual reset", {manual = true, before = desk, probes = {0, 0},
    commands = "id,probe,reset,id,probe", restoreError = "Live routing unavailable",
    notice = "ES-9 reset and streaming verified. Live routing unavailable", want = both})
scenario("slow wake settles", {before = desk, probes = {11, 0}, commands = "id,probe,probe"})
scenario("wake with Live closed", {probes = {11, 11, 0}, commands = "id,probe,probe,reset,id,probe", notice = "Audio restored."})
scenario("manual with Live closed", {manual = true, probes = {0, 0}, commands = "id,probe,reset,id,probe", notice = "ES-9 reset. Audio streaming verified."})
scenario("manual mixed devices", {manual = true, before = dropped, probes = {0, 0}, commands = "id,probe,reset,id,probe", notice = "ES-9 reset. Audio streaming verified.", want = outputOnly})
scenario("Live-only failure", {before = mixed, after = dropped, commands = "id,probe", notice = "Audio restored.", want = outputOnly})
scenario("intentional alternate device", {before = desk, after = {pid = 42, Input = "Push", Output = "Push"}, commands = "id,probe"})
scenario("different Live process", {before = mixed, after = {pid = 43, Input = dropped.Input, Output = dropped.Output}, commands = "id,probe"})
scenario("locked Live recovery after unlock", {locked = true, before = mixed, after = dropped, probes = {0,0}, commands = "id,probe,id,probe", notice = "Audio restored.", want = outputOnly})
scenario("wake error reported once", {probes = {11,11}, commands = "id,probe,probe,reset", resetError = "USB busy", notice = "USB busy"})
scenario("failed verification never reports recovery", {probes = {11,11,11,11,11}, commands = "id,probe,probe,reset,id,probe,probe,probe", notice = "ES-9 reconnected but audio is still stalled."})

-- Exercise the actual selector lookup and readback with both devices present
-- in the menu. With the mic unplugged their channel-count suffixes are identical.
local function checkSelectors(aggregateLabel, input, output, expected, focus)
    local function element(fields)
        fields.setTimeout = function() end
        fields.actionNames = function() return {"AXPress"} end
        return fields
    end
    local window = element({AXTitle = "Settings", AXChildren = {}})
    local root = element({AXWindows = {window}})
    local clicks = {}
    local function selector(direction, initial)
        local control = element({AXDescription = "Audio " .. direction .. " Device", AXValue = initial})
        table.insert(window.AXChildren, control)
        function control:performAction()
            local menu = element({AXTitle = "", AXChildren = {}})
            for _, label in ipairs({es9, aggregateLabel}) do
                local item = element({AXTitle = label})
                function item:performAction()
                    control.AXValue = label
                    table.insert(clicks, direction .. "=" .. label)
                    root.AXFocusedWindow = window
                    return true
                end
                table.insert(menu.AXChildren, item)
            end
            root.AXFocusedWindow = menu
            return true
        end
    end
    selector("Input", input)
    selector("Output", output)
    local elapsed, attempts = 0, 0
    local previous = {pid = function() return 1 end, name = function() return "Other app" end}
    local app = {pid = function() return 42 end, isHidden = function() return false end,
        isRunning = function() return true end,
        activate = function() attempts = attempts + 1; return false end,
        setFrontmost = function() return true end}
    local function foreground()
        if focus and (focus.blocked or attempts < 2 or elapsed < 7) then return previous end
        return app
    end
    hs.application = {
        applicationsForBundleID = function() return {app} end,
        frontmostApplication = foreground
    }
    hs.axuielement = {applicationElement = function() return root end}
    local function sleep(seconds) elapsed = elapsed + seconds; assert(elapsed < 20) end
    local ok, changed = pcall(realLive.restore, 42, both, sleep, function() end)
    if focus and focus.blocked then
        assert(not ok and changed:match("foreground: Other app") and #clicks == 0 and attempts > 1)
        return
    end
    assert(ok, changed)
    assert(table.concat(clicks, ",") == expected and changed == (#expected > 0))
end
for _, state in ipairs({desk, noMic}) do
    checkSelectors(state.Input, "No Device", "No Device", "Output=" .. es9 .. ",Input=" .. state.Input)
    checkSelectors(state.Input, es9, es9, "Input=" .. state.Input)
    checkSelectors(state.Input, state.Input, es9, "")
    checkSelectors(state.Input, "USB Microphone", "Push", "")
end
print("ok - Live selector restoration with and without the mic")

checkSelectors(desk.Input, desk.Input, "No Device", "Output=" .. es9, {})
checkSelectors(desk.Input, desk.Input, "No Device", "", {blocked = true})
print("ok - delayed activation retries and persistent focus failure")
