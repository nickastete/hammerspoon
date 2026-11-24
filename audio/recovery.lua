local live = require("audio.live")
local M = {}
local helper = hs.configdir .. "/audio/es9-helper"
local log = hs.logger.new("ES9", "info")
local wake = hs.caffeinate.watcher
local active, wakeTimer, beforeSleep, waitingForUnlock

local function notify(text)
    hs.notify.new({title = "ES-9 audio", informativeText = text}):send()
end

local function run(manual, saved)
    if active then
        if manual then notify("Audio recovery is already running.") end
        return
    end
    local job = {}
    active = job
    -- All waits yield to Hammerspoon. Strong references keep tasks and timers
    -- alive, and the native helper has its own hard deadline on system calls.
    local function resume(...)
        if active ~= job then return end
        local ok, err = coroutine.resume(job.co, ...)
        if not ok or coroutine.status(job.co) == "dead" then
            if job.cleanup then pcall(job.cleanup) end
            active = nil
            if not ok then
                log.e(tostring(err))
                notify(tostring(err))
            end
        end
    end
    local function sleep(seconds)
        job.timer = hs.timer.doAfter(seconds, resume)
        coroutine.yield()
    end
    local function command(...)
        job.task = hs.task.new(helper, function(code, output, errors)
            resume(code, output:match("^%s*(.-)%s*$"), errors:match("^%s*(.-)%s*$"))
        end, {...})
        if not job.task or not job.task:start() then error("Cannot start es9-helper. Run make audio-helper.", 0) end
        local code, out, err = coroutine.yield()
        if code ~= 0 and code ~= 10 and code ~= 11 then
            error(err ~= "" and err or "ES-9 helper failed (status " .. code .. ")", 0)
        end
        return code, out
    end
    local function absent()
        if manual then notify("ES-9 is disconnected.") end
    end
    job.co = coroutine.create(function()
        local status, oldID = command("id")
        if status == 10 then return absent() end
        local health = command("probe")
        if health == 10 then return absent() end
        if health == 11 and not manual then
            sleep(1)
            health = command("probe")
            if health == 10 then return absent() end
        end
        local current = live.snapshot()
        local lost = live.lost(current, saved)
        if health == 0 and not manual and not lost then return end
        if current and hs.caffeinate.sessionProperties().CGSSessionScreenIsLocked then
            waitingForUnlock = {manual = manual, saved = saved}
            if manual then notify("Audio recovery deferred until unlock.") end
            return
        end
        local wanted = live.intent(current, saved, manual)
        if manual or health == 11 then
            if command("reset", oldID) == 10 then return absent() end
            local newID
            for _ = 1, 16 do
                sleep(0.25)
                local code, id = command("id")
                if code == 0 and id ~= oldID then newID = id; break end
            end
            if not newID then error("ES-9 did not reappear after reset.", 0) end
            local verified = false
            for _ = 1, 3 do
                if command("probe") == 0 then verified = true; break end
                sleep(0.35)
            end
            if not verified then error("ES-9 reconnected but audio is still stalled.", 0) end
            log.i("USB reset " .. oldID .. " -> " .. newID .. ", streaming verified")
        end
        if current then
            live.restore(current.pid, wanted, sleep, function(f) job.cleanup = f end)
        end
        notify((health == 11 or lost) and "Audio restored." or "ES-9 reset. Audio streaming verified.")
    end)
    resume()
end

function M.start(hyper, dismiss)
    M.hotkey = hs.hotkey.bind(hyper, "u", function()
        dismiss()
        run(true)
    end)
    M.watcher = wake.new(function(event)
        if event == wake.systemWillSleep then
            if wakeTimer then wakeTimer:stop() end
            waitingForUnlock = nil
            beforeSleep = live.snapshot()
        elseif event == wake.systemDidWake then
            if wakeTimer then wakeTimer:stop() end
            local saved = beforeSleep
            beforeSleep = nil
            wakeTimer = hs.timer.doAfter(3, function() run(false, saved) end)
        elseif event == wake.screensDidUnlock and waitingForUnlock then
            local request = waitingForUnlock
            waitingForUnlock = nil
            run(request.manual, request.saved)
        end
    end):start()
end

return M
