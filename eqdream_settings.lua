local mq = require('mq')
local M = {}
M.defaults = {autoPull=true, petAssist=true, rest=true, radius=120,
    levelsBelow=4, levelsAbove=1, restHP=90, emergencyHP=35,
    pullMethod=1, pullRange=120, pullRetry=6, pullGem=1,
    autoSnare=false, snareGem=2, snareRetry=10,
    autoHeal=false, healMode=1, healGem=1, healHP=65, healRetry=3}
local bounds = {pullMethod={1,3}, pullRange={10,150}, pullRetry={3,60}, radius={30,150}, levelsBelow={0,10}, levelsAbove={0,3},
    restHP={50,100}, emergencyHP={20,60},
    healMode={1,2}, healGem={1,12}, healHP={20,95}, healRetry={2,30},
    pullGem={1,12}, snareGem={1,12}, snareRetry={5,60}}
function M.identity()
    if mq.TLO.MacroQuest.GameState() ~= 'INGAME' then return nil end
    return (tostring(mq.TLO.EverQuest.Server()) .. '_' .. tostring(mq.TLO.Me.CleanName())):gsub('[^%w_-]','_')
end
function M.path(kind)
    local id=M.identity()
    return id and (mq.configDir .. '/EQDream_' .. id .. '_' .. kind .. '.ini') or nil
end
function M.normalize(c)
    local result={}
    if c.pullMethod==nil and c.autoPull==false then c.pullMethod=3 end
    for k,v in pairs(M.defaults) do
        if type(v)=='boolean' then result[k]=type(c[k])=='boolean' and c[k] or v
        else
            local b=bounds[k]
            result[k]=math.max(b[1],math.min(b[2],math.floor(tonumber(c[k]) or v)))
        end
    end
    -- Lua's and/or idiom cannot represent false as a selected value.
    for k,v in pairs(M.defaults) do
        if type(v)=='boolean' and type(c[k])=='boolean' then result[k]=c[k] end
    end
    result.autoPull=result.pullMethod~=3
    result.restHP=math.max(result.restHP,result.emergencyHP+10)
    return result
end
function M.load()
    local c={}
    local path=M.path('settings')
    local file=path and io.open(path,'r')
    if file then
        for line in file:lines() do
            local k,v=line:match('^(%w+)=(.+)$')
            if k and M.defaults[k]~=nil then
                if type(M.defaults[k])=='boolean' then c[k]=v=='true' else c[k]=tonumber(v) end
            end
        end
        file:close()
    end
    return M.normalize(c)
end
function M.save(c)
    local path=M.path('settings')
    if not path then return false,'Log into a character first.' end
    local file,err=io.open(path,'w')
    if not file then return false,tostring(err) end
    c=M.normalize(c)
    for k in pairs(M.defaults) do file:write(k .. '=' .. tostring(c[k]) .. '\n') end
    file:close()
    return true
end
function M.active(name)
    for pid in tostring(mq.TLO.Lua.PIDs() or ''):gmatch('%d+') do
        local s=mq.TLO.Lua.Script(tonumber(pid))
        local n=tostring(s.Name() or ''):gsub('%.lua$','')
        local status=s.Status()
        if n==name and (status=='RUNNING' or status=='STARTING' or status=='PAUSED') then
            return true,status,tonumber(pid)
        end
    end
    return false,'STOPPED'
end
return M
