local mq = require('mq')
local testPath = mq.TLO.EverQuest.Path() or ''
if not testPath:gsub('\\','/'):gsub('/+$',''):lower():match('/nms%-local$') then
    print('[Tavern Duels] Test client only. Start EQ from NMS-Local.')
    return
end
local queue = mq.configDir .. '/tavern-duels-queue'
local pid = tonumber(mq.TLO.EverQuest.PID())
local lastCharacter, wasInGame = '', false
local function request(action, character)
    local file = io.open(queue .. '/request-' .. tostring(pid) .. '.tmp', 'w')
    if not file then print('[Tavern Duels] Start the Tavern Duels test service first.'); return end
    character = character or ''
    if character ~= '' and not character:match('^[%a][%w_]+$') then file:close(); return end
    file:write(string.format('{"pid":%d,"character":"%s","action":"%s"}', pid, character, action))
    file:close()
    os.remove(queue .. '/request-' .. tostring(pid) .. '.json')
    os.rename(queue .. '/request-' .. tostring(pid) .. '.tmp', queue .. '/request-' .. tostring(pid) .. '.json')
end
mq.bind('/tavern', function(command)
    if command and command:lower() == 'close' then request('close', lastCharacter); return end
    if mq.TLO.MacroQuest.GameState() ~= 'INGAME' then print('[Tavern Duels] Log into your test character first.'); return end
    lastCharacter = mq.TLO.Me.CleanName()
    request('toggle', lastCharacter)
    print('[Tavern Duels] Window toggled. Use /tavern close to close it.')
end)
print('[Tavern Duels] Ready. Type /tavern to open the card game.')
while true do
    local inGame = mq.TLO.MacroQuest.GameState() == 'INGAME'
    local current = inGame and mq.TLO.Me.CleanName() or ''
    if wasInGame and (not inGame or (lastCharacter ~= '' and current ~= lastCharacter)) then request('close', lastCharacter) end
    if inGame then lastCharacter = current end
    wasInGame = inGame
    mq.delay(500)
end
