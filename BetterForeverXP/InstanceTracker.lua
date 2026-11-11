local _, addon = ...

-- Dungeon and raid run accounting is separate from the ordinary level/session
-- counter. Only snapshots observed WHILE inside a supported instance earn XP.
-- Saved data contains plain numbers/strings so it survives /reload and relog.
local function CleanNumber(value)
    return math.max(0, tonumber(value) or 0)
end

local function Snapshot(level, xp, xpMax)
    return { level = CleanNumber(level), xp = CleanNumber(xp), xpMax = CleanNumber(xpMax) }
end

function addon.NewInstanceTracker(saved)
    saved = type(saved) == "table" and saved or {}
    if type(saved.active) ~= "table" then saved.active = nil end
    if type(saved.last) ~= "table" then saved.last = nil end

    local tracker = { saved = saved, inside = false, lastTick = nil }
    local GRACE_SECONDS = 120

    local function SameInstance(run, info)
        return run and info and run.key == info.key
    end

    local function Finish(run)
        if not run then return end
        saved.last = {
            key = run.key, name = run.name, xp = CleanNumber(run.xp),
            elapsed = CleanNumber(run.elapsed), bars = CleanNumber(run.bars),
            completedAt = run.leftAt,
        }
        saved.active = nil
    end

    local function NewRun(info, sample)
        saved.active = {
            key = info.key, name = info.name,
            xp = 0, bars = 0, elapsed = 0, leftAt = nil,
            sample = Snapshot(sample.level, sample.xp, sample.xpMax),
        }
        -- New run replaces the old completed summary; keep only one run.
        saved.last = nil
    end

    -- Call for zone changes, login, and periodic verification. outside grace
    -- avoids fragmenting one dungeon run on a quick exit/death run.
    function tracker:Zone(info, sample, now)
        local run = saved.active
        now = CleanNumber(now)
        if not info then
            tracker.inside = false
            tracker.lastTick = nil
            if run and not run.leftAt then run.leftAt = now end
            if run and now - CleanNumber(run.leftAt) > GRACE_SECONDS then Finish(run) end
            return
        end

        if run and run.leftAt and now - CleanNumber(run.leftAt) > GRACE_SECONDS then
            Finish(run)
            run = nil
        end
        if run and not SameInstance(run, info) then
            Finish(run)
            run = nil
        end
        if not run then
            NewRun(info, sample)
            run = saved.active
        elseif run.leftAt then
            -- The baseline must be replaced after an absence: XP gained outside
            -- a dungeon is never credited to the run when returning.
            run.sample = Snapshot(sample.level, sample.xp, sample.xpMax)
        end
        run.leftAt = nil
        tracker.inside = true
        tracker.lastTick = nil
    end

    function tracker:XP(level, xp, xpMax)
        local run = saved.active
        if not tracker.inside or not run then return end
        local current = Snapshot(level, xp, xpMax)
        local previous = run.sample
        run.sample = current
        if not previous or previous.xpMax <= 0 or current.xpMax <= 0 then return end
        local earned, gainedBars = 0, 0
        if current.level == previous.level and current.xp >= previous.xp then
            earned = current.xp - previous.xp
            gainedBars = earned / previous.xpMax * 20
        elseif current.level == previous.level + 1 then
            -- Previous level remainder plus the new level's current progress.
            -- Use the appropriate level cap for each portion, avoiding
            -- accidental huge negative XP when the level rolls over.
            earned = math.max(0, previous.xpMax - previous.xp) + current.xp
            gainedBars = math.max(0, previous.xpMax - previous.xp) / previous.xpMax * 20
                + current.xp / current.xpMax * 20
        end
        run.xp = CleanNumber(run.xp) + earned
        run.bars = CleanNumber(run.bars) + gainedBars
    end

    -- Called at 1Hz; GetTime() is monotonic in a client session. On reload,
    -- no offline/reload interval is counted because lastTick is ephemeral.
    function tracker:Tick(now)
        if not tracker.inside or not saved.active then
            tracker.lastTick = nil
            return
        end
        now = CleanNumber(now)
        if tracker.lastTick and now >= tracker.lastTick then
            local delta = now - tracker.lastTick
            if delta < 10 then
                saved.active.elapsed = CleanNumber(saved.active.elapsed) + delta
            end
        end
        tracker.lastTick = now
    end

    function tracker:View()
        if tracker.inside and saved.active then return saved.active, true end
        if saved.active then return saved.active, false end
        return saved.last, false
    end

    -- Instant run stats never contaminate the old leveling-session metrics.
    return tracker
end
