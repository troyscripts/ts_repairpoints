local R = RepairPoints
local option = 'ts_repairpoints_repair'
local function detach(id)
    local entry = R.peds[id]
    if not entry then return end
    if GetResourceState('ox_target') == 'started' then exports.ox_target:removeEntity(entry.netId, option) end
    -- De server beheert bestaan/respawn; een client verwijdert nooit de gedeelde ped.
    R.peds[id] = nil
end
local function addTarget(id, entry)
    exports.ox_target:addEntity(entry.netId, {{
        name = option, icon = 'fa-solid fa-screwdriver-wrench', label = 'Reparatieprijs opvragen',
        distance = Config.Ped.TargetDistance,
        canInteract = function(entity)
            local p = R.points[id]
            return p and not p.repairJob and not R.locked and not R.active and not IsEntityDead(entity)
                and #(GetEntityCoords(entity) - R.position(p)) <= Config.Ped.ArrivalDistance
                and not IsPedInAnyVehicle(PlayerPedId(), false)
        end,
        onSelect = function() R.repair(id) end,
    }})
end
local function destination(p, away)
    if not away then return R.position(p) end
    if p.leaveCoords then return vector3(p.leaveCoords.x, p.leaveCoords.y, p.leaveCoords.z) end
    local h = math.rad(p.heading or Config.Ped.Heading)
    return R.position(p) + vector3(-math.sin(h) * Config.Ped.LeaveDistance, math.cos(h) * Config.Ped.LeaveDistance, 0.0)
end
local function walk(entry, p, away)
    local dest = destination(p, away)
    FreezeEntityPosition(entry.entity, false)
    ClearPedTasks(entry.entity)
    TaskFollowNavMeshToCoord(entry.entity, dest.x, dest.y, dest.z, Config.Ped.WalkSpeed, -1, Config.Ped.ArrivalDistance, false, p.heading or Config.Ped.Heading)
    SetPedKeepTask(entry.entity, true)
    entry.phase, entry.destination, entry.lastTask = away and 'leaving' or 'returning', dest, GetGameTimer()
end
function R.workSpot(vehicle)
    local _, maximum = GetModelDimensions(GetEntityModel(vehicle))
    -- Vrije plek voor de voorbumper; ook bij grote voertuigen binnen serverbereik.
    local forward = math.min(5.5, math.max(1.0, maximum.y)) + 0.6
    return GetOffsetFromEntityInWorldCoords(vehicle, 0.0, forward, 0.0)
end
local function work(entry, p)
    local job = p.repairJob
    if not job or R.locked or not NetworkDoesEntityExistWithNetworkId(job.netId) then return false end
    local vehicle = NetToVeh(job.netId)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    local spot = R.workSpot(vehicle)
    if entry.workToken ~= job.token then
        entry.workToken, entry.workTaskAt, entry.working = job.token, 0, false
        ClearPedTasks(entry.entity)
    end
    local distance = #(GetEntityCoords(entry.entity) - spot)
    if distance > 1.2 then
        if entry.working or entry.workTaskAt == 0 or GetGameTimer() - entry.workTaskAt > 10000 then
            ClearPedTasks(entry.entity)
            TaskFollowNavMeshToCoord(entry.entity, spot.x, spot.y, spot.z, Config.Ped.WalkSpeed, -1, 0.7, false, 0.0)
            SetPedKeepTask(entry.entity, true)
            entry.workTaskAt, entry.working = GetGameTimer(), false
        end
    else
        local dict, clip = Config.Ped.AnimationDict, Config.Ped.AnimationClip
        RequestAnimDict(dict)
        if HasAnimDictLoaded(dict) and not IsEntityPlayingAnim(entry.entity, dict, clip, 3) then
            local c, target = GetEntityCoords(entry.entity), GetEntityCoords(vehicle)
            ClearPedTasks(entry.entity)
            SetEntityHeading(entry.entity, GetHeadingFromVector_2d(target.x - c.x, target.y - c.y))
            TaskPlayAnim(entry.entity, dict, clip, 8.0, -8.0, -1, 1, 0.0, false, false, false)
            entry.working = true
        end
    end
    entry.phase = 'working'
    return true
end
local function updatePed(entry, p)
    local ped = entry.entity
    if IsEntityDead(ped) then
        if NetworkHasControlOfEntity(ped) then FreezeEntityPosition(ped, false) end
        entry.controlled = false
        if R.active and R.active.id == entry.id then R.abort('De reparateur is overleden. De reparatie is afgebroken.') end
        return
    end
    -- Alleen de huidige netwerkeigenaar stuurt de taken; alle spelers zien dezelfde ped.
    if not NetworkHasControlOfEntity(ped) then entry.controlled = false; return end
    if not entry.controlled then
        entry.controlled = true; entry.away = nil; entry.workToken = nil
        SetEntityInvincible(ped, false)
        SetEntityCanBeDamaged(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedCanRagdoll(ped, true)
        SetPedDiesWhenInjured(ped, true)
    end
    if work(entry, p) then return end
    if entry.workToken then
        entry.workToken, entry.working, entry.away = nil, false, nil
        ClearPedTasks(ped)
    end
    local away, desired = R.locked, destination(p, R.locked)
    if away ~= entry.away or (entry.destination and #(entry.destination - desired) > 0.2) then
        entry.away = away; walk(entry, p, away)
    end
    if entry.phase == 'leaving' or entry.phase == 'returning' then
        if #(GetEntityCoords(ped) - desired) <= Config.Ped.ArrivalDistance then
            ClearPedTasks(ped)
            if not away then SetEntityHeading(ped, p.heading or Config.Ped.Heading) end
            TaskStandStill(ped, -1)
            -- Niet bevriezen: de ped moet door geweld/aanrijding kunnen vallen en sterven.
            entry.phase = away and 'away' or 'ready'
        elseif GetGameTimer() - entry.lastTask > 15000 then walk(entry, p, away) end
    elseif #(GetEntityCoords(ped) - desired) > Config.Ped.ArrivalDistance + 1.0 then
        walk(entry, p, away)
    end
end
CreateThread(function()
    local warned = false
    while true do
        local targetReady = GetResourceState('ox_target') == 'started'
        for id, entry in pairs(R.peds) do
            local p = R.points[id]
            if not p or R.mode(p) ~= 'ped' or p.pedNetId ~= entry.netId then detach(id)
            elseif NetworkDoesEntityExistWithNetworkId(entry.netId) then
                entry.entity = NetToPed(entry.netId)
                updatePed(entry, p)
            else entry.controlled = false end
        end
        for id, p in pairs(R.points) do
            if R.mode(p) == 'ped' then
                if not targetReady and not warned then
                    print('[ts_repairpoints] Start ox_target voor de ped-interactie.'); warned = true
                end
                if targetReady and p.pedNetId and not R.peds[id] then
                    local entry = { id = id, netId = p.pedNetId }
                    R.peds[id] = entry; addTarget(id, entry)
                end
            end
        end
        Wait(250)
    end
end)
AddEventHandler('onClientResourceStart', function(name)
    if name == 'ox_target' then for id, entry in pairs(R.peds) do addTarget(id, entry) end end
end)
AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then for id in pairs(R.peds) do detach(id) end end
end)
