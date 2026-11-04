local ESX = exports.es_extended:getSharedObject()
local resource = GetCurrentResourceName()
local sessions, vehicleLocks, cooldowns, vehicleCooldowns, requests = {}, {}, {}, {}, {}
local pointLocks = {}
local sequence = 0
local placed, points, locked = {}, {}, true
local raw = LoadResourceFile(resource, 'data/points.json')
if raw then
    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then error('data/points.json is beschadigd; herstel dit bestand.') end
    placed = decoded
    for _, p in ipairs(placed) do p.repairJob = nil; p.pedNetId = nil end
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
    for _, xp in pairs(ESX.GetExtendedPlayers()) do
        local job = xp.getJob()
        if job and Config.MechanicJobs[job.name] then
            if Config.DutyMode == 'job' then return true end
            if Config.DutyMode == 'custom' then
                local ok, duty = pcall(IsRepairMechanicOnDuty, xp, job)
                if not ok or type(duty) ~= 'boolean' or duty then return true end
            elseif job.onDuty == nil or job.onDuty == true then return true end
        end
    end
    return false
end
local function sync() TriggerClientEvent('ts_repairpoints:sync', -1, points, locked) end
local function release(src)
    local s = sessions[src]
    if s and vehicleLocks[s.netId] == src then vehicleLocks[s.netId] = nil end
    sessions[src] = nil
    if s and pointLocks[s.id] == src then pointLocks[s.id] = nil end
    local p = s and points[s.id]
    if p and p.repairJob and p.repairJob.token == s.token then p.repairJob = nil; sync() end
end
local function abort(src, message)
    local s = sessions[src]
    if s and s.phase ~= 'payment' then
        TriggerClientEvent('ts_repairpoints:abort', src, s.token, message)
        release(src)
    end
end
local function refresh()
    local state = mechanicAvailable()
    if state ~= locked then locked = state; sync() end
    local now = os.time()
    for src, s in pairs(sessions) do
        if locked then abort(src, 'Er is een monteur in dienst. De reparatie is afgebroken.')
        elseif now > s.expires or not points[s.id] then abort(src, 'De reparatieaanvraag is verlopen.') end
    end
    for netId, expires in pairs(vehicleCooldowns) do if now >= expires then vehicleCooldowns[netId] = nil end end
end
lib.callback.register('ts_repairpoints:state', function() refresh(); return points, locked end)
CreateThread(function() while true do refresh(); Wait(Config.StatusInterval) end end)
AddEventHandler('esx:setJob', function() SetTimeout(0, refresh) end)
local function valid(src, id, netId, working)
    local p = type(id) == 'string' and points[id]
    local xp = ESX.GetPlayerFromId(src)
    if not p or not xp or type(netId) ~= 'number' or netId <= 0 or netId % 1 ~= 0 then return nil, 'Ongeldig reparatieverzoek.' end
    if mechanicAvailable() then return nil, 'Er is een monteur in dienst. Ga naar de garage.' end
    local ped, vehicle = GetPlayerPed(src), NetworkGetEntityFromNetworkId(netId)
    if ped == 0 or vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return nil, 'Geen geldig voertuig.' end
    if GetEntityHealth(ped) <= 0 then return nil, 'Je kunt nu geen reparatie aanvragen.' end
    if GetPlayerRoutingBucket(src) ~= 0 or GetEntityRoutingBucket(vehicle) ~= 0 then return nil, 'Niet beschikbaar in deze instantie.' end
    local mode = p.interaction or Config.Interaction
    local playerRadius, vehicleRadius = Config.Radius, Config.Radius
    if mode == 'ped' then
        if not RepairPedAlive or not RepairPedAlive(id) then return nil, 'Deze monteur is niet beschikbaar.' end
        if not working and not RepairPedAvailable(id) then return nil, 'De monteur is nog niet terug op zijn plek.' end
        if GetVehiclePedIsIn(ped, false) ~= 0 then return nil, 'Stap uit en spreek de monteur aan.' end
        if GetPedInVehicleSeat(vehicle, -1) ~= 0 then return nil, 'Parkeer de auto en laat de bestuurder uitstappen.' end
        playerRadius, vehicleRadius = working and (Config.VehicleRadius + 3.0) or (Config.Ped.TargetDistance + 1.0), Config.VehicleRadius
    elseif GetVehiclePedIsIn(ped, false) ~= vehicle or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        return nil, 'Je moet de bestuurder zijn.'
    end
    local pos = vector3(p.coords.x, p.coords.y, p.coords.z)
    if #(GetEntityCoords(ped) - pos) > playerRadius + 0.5 or #(GetEntityCoords(vehicle) - pos) > vehicleRadius + 0.5 then return nil, 'Speler of voertuig te ver van het reparatiepunt.' end
    if GetEntitySpeed(vehicle) > 0.5 then return nil, 'Zet het voertuig eerst stil.' end
    return xp, nil, vehicle
end
lib.callback.register('ts_repairpoints:quote', function(src, id, netId)
    local now = os.time()
    if requests[src] and now - requests[src] < 2 then return false, 'Even wachten.' end
    requests[src] = now
    if sessions[src] then return false, 'Je hebt al een reparatieaanvraag openstaan.' end
    if (cooldowns[src] or 0) > now or (vehicleCooldowns[netId] or 0) > now then return false, 'Wacht even voor een nieuwe reparatie.' end
    local xp, err, vehicle = valid(src, id, netId)
    if not xp then return false, err end
    if (points[id].interaction or Config.Interaction) == 'ped' and pointLocks[id] then return false, 'Deze monteur helpt al iemand anders.' end
    if vehicleLocks[netId] then return false, 'Dit voertuig heeft al een reparatieaanvraag.' end
    local quote, reason = RepairVehicleQuote(vehicle)
    if not quote then return false, reason end
    local ready, paymentError = RepairPaymentReady(src, quote.price)
    if not ready then return false, paymentError end
    sequence = sequence + 1
    quote.id, quote.netId, quote.token = id, netId, sequence
    quote.vehicle, quote.model = vehicle, GetEntityModel(vehicle)
    quote.plate = GetVehicleNumberPlateText(vehicle)
    quote.phase, quote.expires = 'quote', now + Config.QuoteLifetime
    sessions[src], vehicleLocks[netId] = quote, src
    if (points[id].interaction or Config.Interaction) == 'ped' then pointLocks[id] = src end
    return true, { token = quote.token, price = quote.price, plate = quote.plate, netId = netId }
end)
local function validateSession(src, token, phase)
    local s = sessions[src]
    if not s or s.token ~= token or s.phase ~= phase then return nil, 'Ongeldige of verlopen reparatieaanvraag.' end
    if os.time() > s.expires then release(src); return nil, 'Prijsopgave verlopen.' end
    local xp, err, vehicle = valid(src, s.id, s.netId, s.phase ~= 'quote')
    if not xp then release(src); return nil, err end
    if vehicle ~= s.vehicle or GetEntityModel(vehicle) ~= s.model or GetVehicleNumberPlateText(vehicle) ~= s.plate then
        release(src); return nil, 'Het geselecteerde voertuig is veranderd.'
    end
    if not RepairDamageMatches(s, vehicle) then release(src); return nil, 'De schade is veranderd. Vraag een nieuwe prijsopgave aan.' end
    return s
end
lib.callback.register('ts_repairpoints:begin', function(src, token)
    local s, err = validateSession(src, token, 'quote')
    if not s then return false, err end
    local p = points[s.id]
    if (p.interaction or Config.Interaction) == 'ped' then
        s.phase = 'walking'
        s.expires = os.time() + math.ceil(Config.Ped.ApproachTimeout / 1000) + 5
        p.repairJob = { token = s.token, netId = s.netId }
        sync()
    else
        s.phase, s.started = 'repair', GetGameTimer()
        s.expires = os.time() + math.ceil(Config.Duration / 1000) + 30
    end
    return true
end)
lib.callback.register('ts_repairpoints:arrived', function(src, token)
    local s, err = validateSession(src, token, 'walking')
    if not s then return false, err end
    if not RepairPedAtVehicle(s.id, s.vehicle) then return false, 'De monteur is nog niet bij de auto.' end
    s.phase, s.started = 'repair', GetGameTimer()
    s.expires = os.time() + math.ceil(Config.Duration / 1000) + 30
    return true
end)
RegisterNetEvent('ts_repairpoints:cancel', function(token)
    local s = sessions[source]
    if s and s.token == token and s.phase ~= 'payment' then release(source) end
end)
lib.callback.register('ts_repairpoints:finish', function(src, token)
    local s, err = validateSession(src, token, 'repair')
    if not s then return false, err end
    if (points[s.id].interaction or Config.Interaction) == 'ped' and not RepairPedAtVehicle(s.id, s.vehicle) then
        release(src); return false, 'De monteur is niet meer bij de auto.'
    end
    if GetGameTimer() - s.started < Config.Duration then release(src); return false, 'Reparatie nog niet voltooid.' end
    s.phase = 'payment' -- replay blokkeren vóór bankexports, voertuigslot behouden
    local paid, paymentError = RepairPayment(src, s.price)
    release(src)
    if not paid then return false, paymentError end
    cooldowns[src], vehicleCooldowns[s.netId] = os.time() + Config.Cooldown, os.time() + Config.Cooldown
    return true, { netId = s.netId, price = s.price }
end)
AddEventHandler('playerDropped', function()
    release(source)
    cooldowns[source], requests[source] = nil, nil
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
    local logAction, logPoint
    local previous = json.encode(placed)
    if args[1] == 'plaatsen' then
        local ped = GetPlayerPed(src)
        if ped == 0 or GetPlayerRoutingBucket(src) ~= 0 then return notify(src, 'Niet beschikbaar op deze locatie.') end
        local c = GetEntityCoords(ped)
        local id = 'placed_' .. os.time()
        local suffix = 1
        while points[id] do suffix = suffix + 1; id = 'placed_' .. os.time() .. '_' .. suffix end
        local label = table.concat(args, ' ', 2)
        placed[#placed + 1] = { id = id, label = label ~= '' and label:sub(1, 60) or 'Reparatiepunt', coords = { x = c.x, y = c.y, z = c.z }, heading = GetEntityHeading(ped) }
        logAction, logPoint = 'placed', placed[#placed]
    elseif args[1] == 'vertrek' then
        local found
        local c = GetEntityCoords(GetPlayerPed(src))
        for _, p in ipairs(placed) do
            if p.id == args[2] then
                if #(c - vector3(p.coords.x, p.coords.y, p.coords.z)) > 100.0 then return notify(src, 'Kies een vertrekplek binnen 100 meter.') end
                p.leaveCoords = { x = c.x, y = c.y, z = c.z }; found = true; break
            end
        end
        if not found then return notify(src, 'Onbekend ID. Vaste punten wijzig je in de config.') end
    elseif args[1] == 'verwijderen' then
        local found
        for i, p in ipairs(placed) do if p.id == args[2] then logAction, logPoint = 'removed', p; table.remove(placed, i); found = true; break end end
        if not found then return notify(src, 'Onbekend ID. Vaste punten verwijder je in de config.') end
    else
        return notify(src, '/reparatiepunt plaatsen [naam] | lijst | verwijderen [id] | vertrek [id]', 'inform')
    end
    local persisted = json.decode(json.encode(placed))
    for _, p in ipairs(persisted) do p.repairJob = nil; p.pedNetId = nil end
    if not SaveResourceFile(resource, 'data/points.json', json.encode(persisted, { indent = true }), -1) then
        placed = json.decode(previous)
        return notify(src, 'Opslaan mislukt. Controleer schrijfrechten van data/points.json.')
    end
    rebuild(); sync(); notify(src, 'Reparatiepunten opgeslagen.', 'success')
    if logAction then RepairLogEvent(logAction, logPoint, src) end
end, false)

RepairServer = {
    points = function() return points end,
    locked = function() return locked end,
    sync = sync,
    abortPoint = function(id, reason)
        for src, s in pairs(sessions) do if s.id == id then abort(src, reason) end end
    end,
}
