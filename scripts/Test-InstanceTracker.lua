-- Pure Lua regression suite; no WoW runtime required.
local addon = {}
assert(loadfile("BetterForeverXP/InstanceTracker.lua"))("BetterForeverXP", addon)
local n = 0
local function eq(actual, expected, name)
    n = n + 1
    assert(actual == expected, name .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local alpha = {key="party:189:Scarlet Monastery", name="Scarlet Monastery"}
local beta = {key="party:90:Gnomeregan", name="Gnomeregan"}
local function sample(level, xp, max)
    return {level=level, xp=xp, xpMax=max}
end
local data = {}
local tracker = addon.NewInstanceTracker(data)
tracker:Zone(alpha, sample(30, 200, 1000), 1000)
local run, inside = tracker:View()
eq(inside, true, "inside first dungeon")
eq(run.xp, 0, "first snapshot is baseline, not earned")
tracker:Tick(100)
tracker:Tick(105)
tracker:XP(30, 450, 1000)
eq(run.xp, 250, "XP earned")
eq(run.bars, 5, "bars gained")
eq(run.elapsed, 5, "time inside")
tracker:Zone(alpha, sample(30,450,1000), 1005)
tracker:Tick(107)
eq(run.elapsed, 7, "polling same dungeon must not reset clock")
-- XP reset can precede the actual level-change event.
tracker:XP(30, 0, 1000)
tracker:XP(31, 150, 1200)
eq(run.xp, 950, "level rollover 550 old + 150 new")
eq(run.bars, 5 + 11 + 2.5, "bars use correct caps across level")
-- Leaving, questing outside, then returning inside the grace.
tracker:Zone(nil, sample(31,150,1200), 1010)
eq(select(2,tracker:View()), false, "outside during grace")
tracker:XP(31, 650, 1200)
eq(run.xp, 950, "no credit for overworld XP")
tracker:Zone(alpha, sample(31,650,1200), 1080)
tracker:XP(31, 750, 1200)
eq(run.xp, 1050, "same run resumes inside grace with fresh XP baseline")
eq(run.elapsed, 7, "outside time not counted")
tracker:Tick(200)
tracker:Tick(201)
eq(run.elapsed, 8, "timer resumes only inside")
-- Reload: a different tracker object points to the same saved character data.
local reloaded = addon.NewInstanceTracker(data)
reloaded:Zone(alpha, sample(31,800,1200), 1085)
reloaded:XP(31,850,1200)
eq(run.xp,1100,"reload does not count XP accrued while not observed")
eq(run.elapsed,8,"reload preserves accumulated duration")
reloaded:Zone(nil, sample(31,850,1200), 1090)
reloaded:Zone(nil, sample(31,850,1200), 1211)
local last,active = reloaded:View()
eq(active,false,"completed run shown as last instance")
eq(last.name, "Scarlet Monastery", "last instance is named")
eq(last.xp, 1100, "last run preserves total")
eq(data.active, nil, "finished run has no active state")
-- A new dungeon starts its own totals and replaces the previous summary.
reloaded:Zone(beta, sample(32,10,1400), 1220)
local nextRun, nextInside = reloaded:View()
eq(nextInside,true,"entered next dungeon")
eq(nextRun.name, "Gnomeregan", "new dungeon")
eq(nextRun.xp,0,"new dungeon starts at zero")
eq(data.last,nil,"old result replaced by new run")
reloaded:XP(32,110,1400)
eq(nextRun.xp,100,"new dungeon tracks independently")
-- A different instance inside the old grace ends the old run immediately.
reloaded:Zone(alpha, sample(32,200,1400), 1230)
local different = select(1,reloaded:View())
eq(different.xp,0,"different dungeon starts immediately")
-- Consecutive same-level XP drops do not manufacture gains.
reloaded:XP(32,50,1400)
reloaded:XP(32,250,1400)
eq(different.xp,50,"same-level XP reset ignored until valid recovery")
-- Reaching the actual level cap inside a dungeon often reports xpMax=0.
-- Credit the final part of the old level without dividing by the missing cap.
local capped = addon.NewInstanceTracker({})
capped:Zone(beta, sample(59, 800, 1000), 2000)
capped:XP(60, 0, 0)
local cappedRun = select(1, capped:View())
eq(cappedRun.xp, 200, "final level remainder counted at cap")
eq(cappedRun.bars, 4, "final level bars counted without next XP cap")

-- The event handler now probes the zone BEFORE recording an XP update.
-- These transitions assert the two branches that handler must distinguish.
local boundary = addon.NewInstanceTracker({})
boundary:Zone(alpha, sample(20, 100, 1000), 3000)
boundary:XP(20, 200, 1000)
eq(select(1, boundary:View()).xp, 100, "inside XP credits normally")
boundary:Zone(nil, sample(20, 250, 1000), 3001)
boundary:XP(20, 250, 1000)
eq(select(1, boundary:View()).xp, 100, "XP event immediately after exit excluded")
boundary:Zone(alpha, sample(20, 300, 1000), 3002)
boundary:XP(20, 350, 1000)
eq(select(1, boundary:View()).xp, 150, "XP event after reentry credits only post-baseline change")

-- Quest reward XP should not masquerade as dungeon-fighting XP.
-- The server may report QUEST_TURNED_IN before or after PLAYER_XP_UPDATE.
local questAfter = addon.NewInstanceTracker({})
questAfter:Zone(alpha, sample(28, 100, 1000), 5000)
questAfter:XP(28, 600, 1000)
questAfter:QuestReward(400)
local qAfter = select(1, questAfter:View())
eq(qAfter.xp, 100, "quest reward after XP event excluded")
eq(qAfter.questXP, 400, "authoritative quest reward retained")
eq(qAfter.bars, 2, "quest reward bars excluded on same level")
questAfter:XP(28, 650, 1000)
eq(qAfter.xp, 150, "later kill XP counted after quest turnin")
eq(qAfter.bars, 3, "later kill bars counted correctly")

local questBefore = addon.NewInstanceTracker({})
questBefore:Zone(alpha, sample(28, 100, 1000), 5000)
questBefore:QuestReward(400)
local qBefore = select(1,questBefore:View())
eq(qBefore.xp, 0, "pending quest reward never shows as negative XP")
questBefore:XP(28, 500, 1000)
eq(qBefore.xp, 0, "quest reward before XP event excluded")
questBefore:XP(28, 600, 1000)
eq(qBefore.xp, 100, "subsequent nonquest XP counted")

-- Level-up with combined quest and mob rewards. Both ledgers persist reload.
local questLevelSave = {}
local questLevel = addon.NewInstanceTracker(questLevelSave)
questLevel:Zone(alpha, sample(28, 900, 1000), 6000)
questLevel:QuestReward(250)
questLevel:XP(29, 200, 1200)
eq(select(1,questLevel:View()).xp, 50, "quest crossing level boundary excluded")
local questReload = addon.NewInstanceTracker(questLevelSave)
questReload:Zone(alpha, sample(29, 200, 1200), 6001)
questReload:XP(29, 250, 1200)
eq(select(1,questReload:View()).xp, 100, "quest ledger survives reload")
questReload:Zone(nil, sample(29,250,1200),6002)
questReload:QuestReward(99)
eq(select(1,questReload:View()).xp, 100, "quest turnin outside instance ignored")
questReload:Zone(nil, sample(29,250,1200),6130)
eq(questReload.saved.last.xp, 100, "completed run reports net XP")
eq(questReload.saved.last.questXP, 250, "last-instance summary preserves excluded quest XP")
eq(questReload.saved.last.bars > 0, true, "completed run retains net bars")

-- Existing test builds with no raw ledgers retain their progress on upgrade.
local old = {active={key=alpha.key,name=alpha.name,xp=100,bars=2,elapsed=20,
    sample=sample(28,200,1000)}}
local migrated = addon.NewInstanceTracker(old)
migrated:Zone(alpha, sample(28,200,1000),7000)
migrated:QuestReward(50)
eq(select(1,migrated:View()).xp, 50, "migration retains earned XP")

print("InstanceTracker regression PASS: " .. n .. " assertions")
