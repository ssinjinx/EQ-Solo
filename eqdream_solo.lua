-- EQ Dream: stationary solo camp, configured per character by /eqd.
-- NMS/server melee handles the multiclass attack procs. This script selects
-- nearby ordinary mobs, pulls with Distant Strike, and manages attack/rest.
-- No movement, corpse interaction, selling, banking, or automatic login.
local mq = require('mq')
local mode = ...
local settings = require('eqdream_settings')
local copies = 0
for pid in tostring(mq.TLO.Lua.PIDs() or ''):gmatch('%d+') do
    local s = mq.TLO.Lua.Script(tonumber(pid))
    if tostring(s.Name() or ''):gsub('%.lua$','') == 'eqdream_solo'
        and (s.Status() == 'RUNNING' or s.Status() == 'STARTING' or s.Status() == 'PAUSED') then
        copies = copies + 1
    end
end
if copies > 1 then print('[EQ Dream Solo] Already running. Use /eqd to manage it.'); return end
local cfg = settings.load()
cfg.character = mq.TLO.Me.CleanName()
cfg.zone = mq.TLO.Zone.ShortName()
cfg.server = mq.TLO.EverQuest.Server()
cfg.zRadius, cfg.pullTimeout, cfg.fightTimeout = 15, 20000, 120000
local running, targetID, started, engaged = true, 0, 0, false
local lowHealthPause = false
local pullAttempts, nextPullAttempt = 0, 0
local ignored = {}
local function number(v, default) return tonumber(v) or default or 0 end
local function log(s)
    print('[EQ Dream Solo] ' .. s)
    local file = io.open(mq.configDir .. '/EQDream-Solo.log', 'a')
    if file then file:write(os.date('%Y-%m-%d %H:%M:%S ') .. s .. '\n'); file:close() end
end
local function inGame() return mq.TLO.MacroQuest.GameState() == 'INGAME' end
local function validSession()
    return inGame() and mq.TLO.Me.CleanName() == cfg.character
        and mq.TLO.Zone.ShortName() == cfg.zone and not mq.TLO.Me.Dead()
        and mq.TLO.EverQuest.Server() == cfg.server
end
local function attackOff()
    if inGame() then mq.cmd('/attack off') end
end
local function stop(reason)
    running = false
    attackOff()
    if inGame() and number(mq.TLO.Me.Pet.ID()) > 0 then mq.cmd('/pet back off') end
    log('Stopped: ' .. reason)
end
if not validSession() then
    log('Log into a living character before starting.')
    return
end
cfg.pullAA = number(mq.TLO.Me.AltAbility('Distant Strike').ID())
if cfg.autoPull and cfg.pullMethod==1 and cfg.pullAA <= 0 then
    log('Distant Strike is unavailable. Select Spell gem or Defend only in /eqd.'); return
end
local function offensiveSpell(gem)
    local spell=mq.TLO.Me.Gem(gem)
    local kind=tostring(spell.TargetType() or '')
    if number(spell.ID())>0 and not spell.Beneficial()
        and (kind=='Single' or kind=='LifeTap' or kind=='Undead' or kind=='Summoned' or kind=='Animal') then return spell end
end
local function spellReady(gem, spell)
    return spell and not mq.TLO.Me.Stunned() and not mq.TLO.Me.Moving()
        and mq.TLO.Me.SpellReady(gem)() and number(mq.TLO.Me.CurrentMana())>=number(spell.Mana())
end
local function spellRange(spell)
    return math.max(0,number(spell.MyRange(),number(spell.Range())))
end
if cfg.autoPull and cfg.pullMethod==2 and not offensiveSpell(cfg.pullGem) then
    log('Select a memorized single-target detrimental Pull spell gem in /eqd before starting.'); return
end
if cfg.pullMethod==2 then cfg.pullTimeout=cfg.pullRetry*3000+15000 end
local offensiveCast
local function waitOffensiveCast()
    if not offensiveCast then return false end
    if mq.TLO.Me.Casting() then
        if mq.gettime()-offensiveCast>30000 then stop('spell cast did not finish') end
        return true
    end
    if mq.gettime()-offensiveCast<1500 then return true end
    offensiveCast=nil
    return false
end
local function canPull()
    if mq.TLO.Me.Casting() then return false end
    if cfg.pullMethod==2 then return spellReady(cfg.pullGem,offensiveSpell(cfg.pullGem)) end
    return mq.TLO.Me.AltAbilityReady('Distant Strike')()
end
local function activatePull()
    if cfg.pullMethod==2 then
        local spell=offensiveSpell(cfg.pullGem)
        if not spellReady(cfg.pullGem,spell) or not running or not validSession()
            or number(mq.TLO.Target.ID())~=targetID then return end
        local s=mq.TLO.Spawn(targetID)
        if not s.LineOfSight() or number(s.Distance(),999)>math.min(cfg.pullRange,spellRange(spell)) then return end
        offensiveCast=mq.gettime()
        mq.cmdf('/cast %d',cfg.pullGem)
        pullAttempts=pullAttempts+1
        nextPullAttempt=mq.gettime()+cfg.pullRetry*1000
    else mq.cmdf('/alt activate %d',cfg.pullAA) end
end
local campX, campY, campZ = mq.TLO.Me.X(), mq.TLO.Me.Y(), mq.TLO.Me.Z()
local function campDistance(s)
    local x, y = s.X(), s.Y()
    if not x or not y then return math.huge end
    return math.sqrt((x - campX)^2 + (y - campY)^2)
end
local function validMob(s)
    return number(s.ID()) > 0 and s.Type() == 'NPC'
        and not s.Dead() and number(s.Master.ID()) == 0
        and campDistance(s) <= cfg.radius
        and math.abs(number(s.Z()) - campZ) <= cfg.zRadius
end
local function validAttacker(s)
    if number(s.ID()) <= 0 or s.Dead() then return false end
    if s.Type() == 'NPC' then return true end
    return s.Type() == 'Pet' and s.Master.Type() == 'NPC'
end
local function selectTarget(id)
    if number(mq.TLO.Target.ID()) ~= id then
        attackOff()
        mq.cmdf('/target id %d', id)
        mq.delay(750, function() return number(mq.TLO.Target.ID()) == id end)
    end
    return number(mq.TLO.Target.ID()) == id
end
local function hater()
    for i = 1, 20 do
        local xt = mq.TLO.Me.XTarget(i)
        if xt.TargetType() == 'Auto Hater' and number(xt.ID()) > 0 then
            local s = mq.TLO.Spawn(xt.ID())
            if validAttacker(s) then return s end
        end
    end
end
local healCast, nextHealAttempt = nil, 0
local healWarnings = {}
local function healWarning(key, message)
    if not healWarnings[key] then log(message); healWarnings[key]=true end
end
local function restoreHealTarget()
    local cast=healCast
    healCast=nil
    if not cast or not validSession() then return end
    -- Respect a target the player changed during casting.
    if number(mq.TLO.Target.ID())~=cast.target then return end
    if cast.previous>0 and cast.previous~=cast.target then
        local previous=mq.TLO.Spawn(cast.previous)
        if number(previous.ID())>0 and not previous.Dead() then selectTarget(cast.previous) end
    elseif cast.previous==0 and cfg.healMode==1 then
        mq.cmd('/target clear')
    end
end
local function autoHeal(aggro)
    local now=mq.gettime()
    if healCast then
        if mq.TLO.Me.Casting() then
            if now-healCast.started>30000 then stop('healing cast did not finish'); end
            return true
        end
        -- Allow the client to report a newly requested cast (also covers instant heals).
        if now-healCast.started<1500 then return true end
        restoreHealTarget()
        nextHealAttempt=now+cfg.healRetry*1000
        return true
    end
    -- Never retarget, sit, or pull during any cast, including manual casts.
    if mq.TLO.Me.Casting() then return true end
    if not cfg.autoHeal or now<nextHealAttempt or number(mq.TLO.Me.PctHPs())>cfg.healHP then return false end
    if mq.TLO.Me.Stunned() or mq.TLO.Me.Moving() then return false end
    local spell=mq.TLO.Me.Gem(cfg.healGem)
    if number(spell.ID())<=0 then
        healWarning('empty','Auto-heal: selected spell gem is empty. Stop and choose a memorized healing spell in /eqd.')
        return false
    end
    local kind=tostring(spell.TargetType() or '')
    local healTarget
    if cfg.healMode==1 then
        local allowed=kind=='Self' or kind=='Single' or kind=='Single Friendly (or Target\'s Target)'
            or kind=='Group v1' or kind=='Group v2' or kind=='Single in Group'
        if not spell.Beneficial() or not allowed then
            healWarning('type','Auto-heal: self-heal mode needs a beneficial spell that can heal you. Use Lifetap mode for taps.')
            return false
        end
        healTarget=number(mq.TLO.Me.ID())
    else
        if kind~='LifeTap' then
            healWarning('type','Auto-heal: lifetap mode needs a single-target LifeTap spell, such as Lifespike.')
            return false
        end
        -- A tap must not initiate combat or hit an unrelated selected NPC.
        if not aggro or not validAttacker(aggro) or not aggro.LineOfSight() then return false end
        if number(aggro.Distance(),999)>number(spell.MyRange(),number(spell.Range())) then return false end
        healTarget=number(aggro.ID())
    end
    if not mq.TLO.Me.SpellReady(cfg.healGem)() or number(mq.TLO.Me.CurrentMana())<number(spell.Mana()) then return false end
    local previous=number(mq.TLO.Target.ID())
    nextHealAttempt=now+cfg.healRetry*1000
    if healTarget<=0 or not selectTarget(healTarget) then return false end
    if not running or not validSession() then return true end
    attackOff()
    mq.cmd('/stand')
    healCast={previous=previous,target=healTarget,started=mq.gettime()}
    mq.cmdf('/cast %d',cfg.healGem)
    return true
end
local snares={}
local function autoSnare(aggro)
    if not cfg.autoSnare or not aggro or not validAttacker(aggro) then return false end
    local id=number(aggro.ID())
    -- Snare the enemy we are already fighting, not an unrelated add.
    if targetID>0 and targetID~=id then return false end
    local now=mq.gettime()
    local state=snares[id] or {attempts=0,next=0}
    snares[id]=state
    if now<state.next then return false end
    local spell=offensiveSpell(cfg.snareGem)
    if not spell then
        healWarning('snare','Auto snare: select a memorized single-target snare spell in /eqd.')
        return false
    end
    if not spellReady(cfg.snareGem,spell) or not aggro.LineOfSight()
        or number(aggro.Distance(),999)>spellRange(spell) then return false end
    if not selectTarget(id) or not running or not validSession() then return false end
    if number(mq.TLO.Target.Snared.ID())>0 then
        state.attempts=0; state.next=now+2000
        return false
    end
    if state.attempts>=3 then
        state.attempts=0; state.next=now+60000
        return false
    end
    attackOff(); mq.cmd('/stand')
    state.attempts=state.attempts+1
    state.next=mq.gettime()+cfg.snareRetry*1000
    offensiveCast=mq.gettime()
    mq.cmdf('/cast %d',cfg.snareGem)
    return true
end
local function freshMob()
    local level = number(mq.TLO.Me.Level())
    local range=cfg.radius
    if cfg.pullMethod==2 then
        local spell=offensiveSpell(cfg.pullGem)
        if not spell then return end
        range=math.min(range,cfg.pullRange,spellRange(spell))
    end
    local query = string.format('npc targetable los radius %d zradius %d range %d %d',
        math.floor(range), cfg.zRadius, math.max(1, level - cfg.levelsBelow), level + cfg.levelsAbove)
    for i = 1, math.min(50, number(mq.TLO.SpawnCount(query)())) do
        local s = mq.TLO.NearestSpawn(i, query)
        local id = number(s.ID())
        if validMob(s) and not s.Named() and s.LineOfSight()
            and number(s.PctHPs()) == 100
            and (not ignored[id] or mq.gettime() > ignored[id]) then
            return s
        end
    end
end
if mode == 'check' then
    local ok, err = pcall(function()
        log('Character and zone accepted. Level: ' .. tostring(mq.TLO.Me.Level()))
        log('Pull method: ' .. tostring(cfg.pullMethod))
        log('Distant Strike ready: ' .. tostring(mq.TLO.Me.AltAbilityReady('Distant Strike')()))
        log('Distant Strike ID: ' .. tostring(mq.TLO.Me.AltAbility('Distant Strike').ID()))
        local a, s = hater(), freshMob()
        log('Attacker: ' .. tostring(a and a.CleanName() or 'none'))
        log('Eligible pull: ' .. tostring(s and s.CleanName() or 'none in range'))
    end)
    log(ok and 'Check passed; no actions taken.' or ('Check failed: ' .. tostring(err)))
    return
end
mq.bind('/eqdstop', function() stop('manual stop') end)
local function run()
    log('Stationary camp started. Pull radius ' .. cfg.radius .. '; stop with /eqdstop.')
    log('Keep NMS loot enabled. Stay for the first fights to verify this setup.')
    while running do
        if not validSession() then stop('character died, zoned, or changed'); break end
        if campDistance(mq.TLO.Me) > 20 then stop('you moved away from the camp'); break end
        if number(mq.TLO.Me.PctHPs()) <= cfg.emergencyHP then
            if not mq.TLO.Me.Casting() and mq.TLO.Me.AbilityReady('Mend')() then mq.cmd('/doability "Mend"') end
            if not lowHealthPause then log('Low health: new pulls paused; continuing defense.') end
            lowHealthPause = true
        elseif lowHealthPause and number(mq.TLO.Me.PctHPs()) >= cfg.restHP then
            lowHealthPause = false
            log('Health recovered; pulling may resume.')
        end
        local aggro = hater()
        if waitOffensiveCast() or autoHeal(aggro) or autoSnare(aggro) then
            -- One cast owns the target at a time; healing precedes new snares.
        elseif targetID > 0 then
            local s = mq.TLO.Spawn(targetID)
            if not validAttacker(s) then
                snares[targetID]=nil
                attackOff(); targetID = 0; engaged = false
            elseif campDistance(s) > cfg.radius and not aggro then
                stop('target left the camp boundary'); break
            elseif mq.gettime() - started > (engaged and cfg.fightTimeout or cfg.pullTimeout) then
                if engaged or aggro then stop('fight timed out'); break end
                ignored[targetID] = mq.gettime() + 60000
                attackOff(); targetID = 0
            elseif selectTarget(targetID) then
                local distance = number(s.Distance(), 999)
                if distance <= math.min(25, number(s.MaxRangeTo(), 15)) then
                    mq.cmd('/stand')
                    mq.cmd('/face fast')
                    if not mq.TLO.Me.Combat() then mq.cmd('/attack on') end
                    if not engaged then
                        engaged = true; started = mq.gettime()
                        if cfg.petAssist and number(mq.TLO.Me.Pet.ID()) > 0 then mq.cmd('/pet attack') end
                    end
                else
                    attackOff()
                    if cfg.pullMethod==2 and not engaged and not aggro
                        and mq.gettime()>=nextPullAttempt then
                        if pullAttempts>=3 then stop('Pull failed after three spell attempts. Check your spell gem, target restrictions and resists in /eqd.'); break end
                        if canPull() and s.LineOfSight()
                            and distance<=cfg.pullRange and number(s.PctHPs())==100 then
                            mq.cmd('/stand'); mq.cmd('/face fast'); activatePull()
                        end
                    end
                end
            else
                stop('could not select target'); break
            end
        elseif aggro then
            targetID = number(aggro.ID()); started = mq.gettime(); engaged = false
        elseif (cfg.rest or lowHealthPause) and number(mq.TLO.Me.PctHPs()) < cfg.restHP then
            attackOff()
            if not mq.TLO.Me.Sitting() then mq.cmd('/sit') end
        elseif cfg.autoPull and canPull() then
            local s = freshMob()
            if s and selectTarget(number(s.ID())) then
                mq.cmd('/stand')
                mq.cmd('/face fast')
                targetID = number(s.ID()); started = mq.gettime(); engaged = false
                pullAttempts=0; nextPullAttempt=0
                log('Pulling ' .. tostring(s.CleanName()))
                if s.LineOfSight() and number(s.PctHPs()) == 100 then
                    activatePull()
                else
                    targetID = 0
                end
            end
        end
        mq.delay(500)
    end
end
local ok, err = xpcall(run, debug.traceback)
if not ok then stop('script error: ' .. tostring(err)) end
restoreHealTarget()
attackOff()
mq.unbind('/eqdstop')

