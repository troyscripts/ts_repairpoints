local ESX = exports.es_extended:getSharedObject()
local resource = GetCurrentResourceName()
local sessions, cooldowns, requests = {}, {}, {}
local placed, points, locked = {}, {}, true
local raw = LoadResourceFile(resource, 'data/points.json')
if raw then
    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then
        error('data/points.json is beschadigd; herstel het bestand voordat je de resource start.')
    end
    placed = decoded
end
local function rebuild()
    points = {}
    for _, p in ipairs(Config.Points) do points[p.id] = p end
    for _, p in ipairs(placed) do points[p.id] = p end
end
rebuild()
local function notify(src, msg, kind)
    TriggerClientEvent('ox_lib:notify', src, { title = 'Reparatiepunt', description = msg, type = kind or 'error' })
end
local function mechanicAvailable()
    for _, xPlayer in pairs(ESX.GetExtendedPlayers()) do
        local job = xPlayer.getJob()
        if job and Config.MechanicJobs[job.name] then
            if Config.DutyMode == 'job' then return true end
            if Config.DutyMode == 'custom' then
                local ok, duty = pcall(IsRepairMechanicOnDuty, xPlayer, job)
                if not ok or type(duty) ~= 'boolean' then
                    return true -- bij een defecte koppeling veilig gesloten
                end
                if duty then return true end
            elseif job.onDuty == nil or job.onDuty == true then
                return true
            end
        end
    end
    return false
end
local function sync(target)
    TriggerClientEvent('ts_repairpoints:sync', target or -1, points, locked)
end
local function refresh()
    local state = mechanicAvailable()
    if state ~= locked then locked = state; sync() end
end
lib.callback.register('ts_repairpoints:state', function() refresh(); return points, locked end)
CreateThread(function()
    while true do refresh(); Wait(Config.StatusInterval) end
end)
AddEventHandler('esx:setJob', function() SetTimeout(0, refresh) end)
local function valid(src, id, netId)
    local p = type(id) == 'string' and points[id]
    local xp = ESX.GetPlayerFromId(src)
    if not p or not xp or type(netId) ~= 'number' or netId % 1 ~= 0 then return nil, 'Ongeldig reparatieverzoek.' end
    if mechanicAvailable() then return nil, 'Er is een monteur in dienst. Ga naar de garage.' end
    local ped = GetPlayerPed(src)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if ped == 0 or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return nil, 'Geen geldig voertuig.' end
    if GetEntityHealth(ped) <= 0 or GetEntityHealth(veh) <= 0 then return nil, 'Dit voertuig kan nu niet worden gerepareerd.' end
    if GetVehiclePedIsIn(ped, false) ~= veh or GetPedInVehicleSeat(veh, -1) ~= ped then return nil, 'Je moet de bestuurder zijn.' end
    if GetPlayerRoutingBucket(src) ~= 0 or GetEntityRoutingBucket(veh) ~= 0 then return nil, 'Niet beschikbaar in deze instantie.' end
    local pos = vector3(p.coords.x, p.coords.y, p.coords.z)
    if #(GetEntityCoords(ped) - pos) > Config.Radius + 1.0 or #(GetEntityCoords(veh) - pos) > Config.Radius + 1.0 then return nil, 'Je bent te ver van het reparatiepunt.' end
    if GetEntitySpeed(veh) > 0.5 then return nil, 'Zet je voertuig eerst stil.' end
    return xp
end
lib.callback.register('ts_repairpoints:begin', function(src, id, netId)
    local now = os.time()
    if requests[src] and now - requests[src] < 2 then return false, 'Even wachten.' end
    requests[src] = now
    if sessions[src] and now <= sessions[src].expires then return false, 'Er loopt al een reparatie.' end
    if cooldowns[src] and now < cooldowns[src] then return false, 'Wacht even voordat je opnieuw repareert.' end
    local xp, err = valid(src, id, netId)
    if not xp then return false, err end
    local ready, paymentError = RepairPaymentReady(src)
    if not ready then return false, paymentError end
    sessions[src] = { id = id, netId = netId, started = GetGameTimer(), expires = now + math.ceil(Config.Duration / 1000) + 30 }
    return true
end)
RegisterNetEvent('ts_repairpoints:cancel', function() sessions[source] = nil end)
lib.callback.register('ts_repairpoints:finish', function(src)
    local session = sessions[src]
    sessions[src] = nil -- eenmalig; ook bij misbruik of afwijzing
    if not session or os.time() > session.expires then return false, 'Reparatie verlopen.' end
    if GetGameTimer() - session.started < Config.Duration then return false, 'Reparatie nog niet voltooid.' end
    local xp, err = valid(src, session.id, session.netId)
    if not xp then return false, err end
    local paid, paymentError = RepairPayment(src)
    if not paid then return false, paymentError end
    cooldowns[src] = os.time() + Config.Cooldown
    return true, session.netId
end)
AddEventHandler('playerDropped', function()
    sessions[source], cooldowns[source], requests[source] = nil, nil, nil
    SetTimeout(0, refresh)
end)
RegisterCommand('reparatiepunt', function(src, args)
    if src == 0 then return end
    local xp = ESX.GetPlayerFromId(src)
    if not xp or not (Config.AdminGroups[xp.getGroup()] or IsPlayerAceAllowed(src, 'ts_repairpoints.admin')) then return notify(src, 'Geen toestemming.') end
    if args[1] == 'lijst' then
        local lines = {}
        for id, p in pairs(points) do lines[#lines + 1] = id .. ': ' .. p.label end
        table.sort(lines)
        return notify(src, #lines > 0 and table.concat(lines, '\n') or 'Er zijn nog geen reparatiepunten.', 'inform')
    end
    local previous = json.encode(placed)
    if args[1] == 'plaatsen' then
        local ped = GetPlayerPed(src)
        if ped == 0 or GetPlayerRoutingBucket(src) ~= 0 then return notify(src, 'Niet beschikbaar op deze locatie.') end
        local c = GetEntityCoords(ped)
        local id = 'placed_' .. os.time()
        local suffix = 1
        while points[id] do suffix = suffix + 1; id = 'placed_' .. os.time() .. '_' .. suffix end
        local label = table.concat(args, ' ', 2)
        placed[#placed + 1] = { id = id, label = label ~= '' and label:sub(1, 60) or 'Reparatiepunt', coords = { x = c.x, y = c.y, z = c.z } }
    elseif args[1] == 'verwijderen' then
        local found
        for i, p in ipairs(placed) do if p.id == args[2] then table.remove(placed, i); found = true; break end end
        if not found then return notify(src, 'Onbekend ID. Vaste punten verwijder je in de config.') end
    else
        return notify(src, '/reparatiepunt plaatsen [naam] | lijst | verwijderen [id]', 'inform')
    end
    if not SaveResourceFile(resource, 'data/points.json', json.encode(placed, { indent = true }), -1) then
        placed = json.decode(previous)
        return notify(src, 'Opslaan mislukt. Controleer schrijfrechten van data/points.json.')
    end
    rebuild(); sync(); notify(src, 'Reparatiepunten opgeslagen.', 'success')
end, false)
