local mq = require('mq')
local ImGui = require('ImGui')
local settings = require('eqdream_settings')
local mode=...
-- Keep the command available across zoning without duplicate windows.
local copies=0
for pid in tostring(mq.TLO.Lua.PIDs() or ''):gmatch('%d+') do
    local s=mq.TLO.Lua.Script(tonumber(pid))
    if tostring(s.Name() or ''):gsub('%.lua$','')=='eqdream_control'
        and (s.Status()=='RUNNING' or s.Status()=='STARTING') then copies=copies+1 end
end
if copies>1 then return end
local visible=mode~='quiet'
local config=settings.load()
local identity=settings.identity()
local action,dirty,message=nil,false,''
local active,status=false,'STOPPED'
local function command(arg)
    arg=(arg or ''):lower()
    if arg=='start' or arg=='stop' then action=arg; visible=true
    elseif arg=='hide' then visible=false
    elseif arg=='show' then visible=true
    else visible=not visible end
end
mq.bind('/eqd',command)
local function checkbox(label,key)
    local value=ImGui.Checkbox(label,config[key])
    if value~=config[key] then config[key]=value; dirty=true end
end
local function slider(label,key,minimum,maximum)
    ImGui.SetNextItemWidth(160)
    local value=ImGui.SliderInt(label,config[key],minimum,maximum)
    if value~=config[key] then config[key]=value; dirty=true end
end
local function draw()
    if not visible or not identity then return end
    ImGui.SetNextWindowSize(400,550,ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowPos(30,350,ImGuiCond.FirstUseEver)
    local show
    visible,show=ImGui.Begin('EQ Dream | Solo Assist###EQDreamSolo',visible)
    if show then
        ImGui.Text(tostring(mq.TLO.Me.CleanName()) .. '  |  ' .. tostring(mq.TLO.Zone.ShortName()))
        ImGui.Text(active and ('Status: ' .. status) or 'Status: Stopped')
        if active then
            if ImGui.Button('Stop',150,30) then action='stop' end
        else
            if ImGui.Button('Start at my position',190,30) then action='start' end
        end
        ImGui.SameLine()
        if ImGui.Button('Hide',65,30) then visible=false end
        ImGui.Separator()
        ImGui.BeginDisabled(active)
        local methods={'Distant Strike','Spell gem','Defend only'}
        if ImGui.BeginCombo('Pull method',methods[config.pullMethod]) then
            for i,name in ipairs(methods) do
                if ImGui.Selectable(name,config.pullMethod==i) then config.pullMethod=i; dirty=true end
            end
            ImGui.EndCombo()
        end
        if config.pullMethod==2 then
            slider('Pull spell gem','pullGem',1,12)
            ImGui.TextWrapped('Pull spell: '..tostring(mq.TLO.Me.Gem(config.pullGem).Name() or '(empty)'))
            slider('Maximum pull range','pullRange',10,150)
            slider('Retry seconds','pullRetry',3,60)
            ImGui.TextWrapped('Memorize a single-target detrimental spell in this gem. Checks spell range, mana and cooldown. Three attempts, then stops if no attacker arrives.')
        end
        checkbox('Auto snare','autoSnare')
        if config.autoSnare then
            slider('Snare spell gem','snareGem',1,12)
            ImGui.TextWrapped('Snare spell: '..tostring(mq.TLO.Me.Gem(config.snareGem).Name() or '(empty)'))
            slider('Snare retry seconds','snareRetry',5,60)
            ImGui.TextWrapped('Choose your single-target snare spell. Snares an existing attacker, skips visible snares, and retries failures at this interval. Three unconfirmed attempts cause a 60-second pause. Healing has priority.')
        end
        checkbox('Send my pet into combat','petAssist')
        checkbox('Rest between fights','rest')
        slider('Pull radius','radius',30,150)
        slider('Levels below me','levelsBelow',0,10)
        slider('Levels above me','levelsAbove',0,3)
        slider('Rest until HP %','restHP',50,100)
        slider('Pause pulls at HP %','emergencyHP',20,60)
        ImGui.Separator()
        checkbox('Auto self-heal','autoHeal')
        if config.autoHeal then
            local healing={'Self-heal spell','Lifetap on my attacker'}
            if ImGui.BeginCombo('Healing method',healing[config.healMode]) then
                for i,name in ipairs(healing) do
                    if ImGui.Selectable(name,config.healMode==i) then config.healMode=i; dirty=true end
                end
                ImGui.EndCombo()
            end
            slider('Healing spell gem','healGem',1,12)
            local spell=mq.TLO.Me.Gem(config.healGem)
            ImGui.TextWrapped('Selected spell: '..tostring(spell.Name() or '(empty)'))
            slider('Heal at HP %','healHP',20,95)
            slider('Heal retry seconds','healRetry',2,30)
            ImGui.TextWrapped('Memorize your healing spell in this gem. Self-heal targets you; lifetap requires an attacker already fighting you. Checks mana and cooldown. Stop and Start to apply changes.')
        end
        ImGui.EndDisabled()
        ImGui.Separator()
        ImGui.TextWrapped('Settings save per character. Stop before changing them.')
        ImGui.TextWrapped('Low HP pauses new pulls; defense continues. Stops on zoning, death, or moving away. NMS handles loot.')
        if message~='' then ImGui.TextWrapped(message) end
        ImGui.TextWrapped('/eqd opens this window. Closing it keeps combat running.')
    end
    ImGui.End()
end
mq.imgui.init('EQDreamSoloControl',draw)
while true do
    local nextIdentity=settings.identity()
    if nextIdentity~=identity then
        identity=nextIdentity; config=settings.load(); dirty=false; message=''; action=nil
    end
    active,status=settings.active('eqdream_solo')
    if dirty and identity then
        config=settings.normalize(config)
        local ok,err=settings.save(config)
        message=ok and 'Settings saved.' or ('Save failed: '..tostring(err))
        dirty=false
    end
    if action=='start' and identity and not active then
        local ok,err=settings.save(config)
        if ok then mq.cmd('/lua run eqdream_solo'); message='Starting at your current position.'
        else message='Cannot start: '..tostring(err) end
    elseif action=='stop' and active then
        if status=='PAUSED' then mq.cmd('/lua pause eqdream_solo'); mq.delay(100) end
        mq.cmd('/eqdstop'); message='Stop requested.'
    end
    action=nil
    mq.delay(200)
end
