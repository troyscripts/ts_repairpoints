local ESX = exports.es_extended:getSharedObject()
local peds, netLookup, attacks = {}, {}, {}
local stopping = false
local function position(p) return vector3(p.coords.x, p.coords.y, p.coords.z) end
local function playerIdentity(src)
    local xp = ESX.GetPlayerFromId(src)
    return xp and (xp.identifier or (xp.getIdentifier and xp.getIdentifier()))
end
local function remove(id)
    local e = peds[id]
    if not e then return end
    netLookup[e.netId], attacks[e.netId] = nil, nil
    if DoesEntityExist(e.entity) then DeleteEntity(e.entity) end
    peds[id] = nil
end
local function spawn(id, p)
    local c = p.coords
    local entity = CreatePed(4, joaat(p.pedModel or Config.Ped.Model), c.x, c.y, c.z - 1.0, p.heading or Config.Ped.Heading, true, true)
    if entity == 0 then return end
    local deadline = GetGameTimer() + 5000
    while not DoesEntityExist(entity) and GetGameTimer() < deadline do Wait(50) end
    if not DoesEntityExist(entity) then return end
    SetEntityOrphanMode(entity, 2) -- netwerkped behouden bij eigenaar-migratie/disconnect
    SetEntityRoutingBucket(entity, 0)
    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId == 0 then DeleteEntity(entity); return end
    peds[id] = { entity = entity, netId = netId }
    netLookup[netId] = id
    p.pedNetId = netId
    RepairServer.sync()
end
local function markAttack(src, netId, lethal)
    local id = netLookup[netId]
    local e = id and peds[id]
    if not e or e.processed or not GetPlayerName(src) or not DoesEntityExist(e.entity) then return end
    local player = GetPlayerPed(src)
    if player == 0 or GetPlayerRoutingBucket(src) ~= 0 then return end
    if #(GetEntityCoords(player) - GetEntityCoords(e.entity)) > 300.0 then return end
    local who = playerIdentity(src)
    if not who then return end
    attacks[netId] = { identifier = who, time = GetGameTimer(), lethal = lethal == true }
end
AddEventHandler('weaponDamageEvent', function(sender, data)
    local src = tonumber(sender)
    if not src or type(data) ~= 'table' then return end
    if type(data.hitGlobalId) == 'number' then markAttack(src, data.hitGlobalId, data.willKill) end
    if type(data.hitGlobalIds) == 'table' then
        for i = 1, math.min(#data.hitGlobalIds, 16) do
            if type(data.hitGlobalIds[i]) == 'number' then markAttack(src, data.hitGlobalIds[i], data.willKill) end
        end
    end
end)
local function sourceOfDeath(entity)
    -- OneSync geeft de daadwerkelijke doodsoorzaak als server-entity terug.
    local ok, killer = pcall(GetPedSourceOfDeath, entity)
    if not ok or not killer or killer == 0 or not DoesEntityExist(killer) then return nil end
    if GetEntityType(killer) == 2 then killer = GetPedInVehicleSeat(killer, -1) end
    if killer == 0 then return nil end
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if src and GetPlayerPed(src) == killer then return playerIdentity(src) end
    end
end
function RepairPedAlive(id)
    local e = peds[id]
    return e and not e.deadAt and DoesEntityExist(e.entity) and GetEntityHealth(e.entity) > 0
end
function RepairPedAvailable(id)
    local e, p = peds[id], RepairServer.points()[id]
    if not p or not RepairPedAlive(id) or RepairServer.locked() or p.repairJob then return false end
    return #(GetEntityCoords(e.entity) - position(p)) <= Config.Ped.ArrivalDistance + 0.75
end
function RepairPedAtVehicle(id, vehicle)
    local e = peds[id]
    return RepairPedAlive(id) and DoesEntityExist(vehicle)
        and #(GetEntityCoords(e.entity) - GetEntityCoords(vehicle)) <= Config.Ped.WorkDistance
end
local function processDeath(id, e, p)
    e.processed = true -- één politiebericht en één dossier per daadwerkelijke dood
    local c = GetEntityCoords(e.entity)
    local coords = { x = c.x, y = c.y, z = c.z }
    local ok = pcall(function()
        exports.ts_bridge:AlertJobs(Config.PedDeath.PoliceJobs, {
            title = 'Reparateur gedood', description = ('Er is een reparateur gedood bij %s. Ga ter plaatse.'):format(p.label)
        }, coords, Config.PedDeath.AlertSeconds)
    end)
    if not ok then print('[ts_repairpoints] Politiemelding mislukt bij ' .. id) end
    local hit = attacks[e.netId]
    local who = e.killerIdentifier or sourceOfDeath(e.entity)
    -- Alleen een recente lethal-hit als noodpad, en uitsluitend bij bevestigde dood.
    if not who and hit and hit.lethal and e.deathTick - hit.time <= 5000 and e.deathTick - hit.time >= -3000 then who = hit.identifier end
    if who then RepairCreateCompensation(who, id)
    else print('[ts_repairpoints] Dood reparateur ' .. id .. ': geen bevestigde speler als dader; niemand automatisch belast.') end
    attacks[e.netId] = nil
end
CreateThread(function()
    while not stopping do
        local points = RepairServer.points()
        for id, e in pairs(peds) do
            local p = points[id]
            if not p or (p.interaction or Config.Interaction) ~= 'ped' then
                remove(id)
            elseif not DoesEntityExist(e.entity) then
                remove(id); p.pedNetId = nil; RepairServer.sync()
            else
                if p.pedNetId ~= e.netId then p.pedNetId = e.netId; RepairServer.sync() end
                if not e.deadAt and GetEntityHealth(e.entity) <= 0 then
                    e.deadAt, e.deathTick = os.time(), GetGameTimer()
                    e.killerIdentifier = sourceOfDeath(e.entity)
                    FreezeEntityPosition(e.entity, false)
                    RepairServer.abortPoint(id, 'De reparateur is overleden. De reparatie is afgebroken.')
                end
                if e.deadAt then
                    -- Geef de schadesynchronisatie kort tijd om de doodsoorzaak door te geven.
                    if not e.processed and GetGameTimer() - e.deathTick >= 2000 then processDeath(id, e, p) end
                    if os.time() - e.deadAt >= Config.PedDeath.RespawnSeconds then
                        remove(id); p.pedNetId = nil; spawn(id, p)
                    end
                end
            end
        end
        for id, p in pairs(points) do
            if (p.interaction or Config.Interaction) == 'ped' and not peds[id] then spawn(id, p) end
        end
        Wait(500)
    end
end)
AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    stopping = true
    for id in pairs(peds) do remove(id) end
end)
