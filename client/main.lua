RepairPoints = { points = {}, locked = true, active = nil, peds = {} }
local R = RepairPoints
local blips, shown = {}, false
function R.mode(p) return p.interaction or Config.Interaction end
function R.position(p) return vector3(p.coords.x, p.coords.y, p.coords.z) end
function R.notify(message, kind)
    lib.notify({ title = 'Reparatiepunt', description = message, type = kind or 'error' })
end
local function hide()
    if shown then lib.hideTextUI(); shown = false end
end
function R.abort(message)
    local op = R.active
    if not op or op.payment then return end
    op.cancelled = true
    if op.progress and lib.progressActive() then lib.cancelProgress() end
    if op.dialog then lib.closeAlertDialog() end
    if message and not op.abortMessage then op.abortMessage = message end
end
RegisterNetEvent('ts_repairpoints:abort', function(token, message)
    if R.active and R.active.token == token then R.abort(message) end
end)
local function applyState(data, unavailable)
    R.points, R.locked = data or {}, unavailable ~= false
    for _, b in ipairs(blips) do RemoveBlip(b) end
    blips = {}
    if Config.Blips and not R.locked then
        for _, p in pairs(R.points) do
            local b = AddBlipForCoord(p.coords.x, p.coords.y, p.coords.z)
            SetBlipSprite(b, 402); SetBlipColour(b, 2); SetBlipScale(b, 0.65); SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING'); AddTextComponentString(p.label); EndTextCommandSetBlipName(b)
            blips[#blips + 1] = b
        end
    end
    if R.locked then hide(); R.abort('Er is een monteur in dienst. De reparatie is afgebroken.') end
end
RegisterNetEvent('ts_repairpoints:sync', applyState)
CreateThread(function()
    local data, unavailable = lib.callback.await('ts_repairpoints:state', false)
    applyState(data, unavailable)
end)
local function eligible(vehicle, p)
    return vehicle ~= 0 and DoesEntityExist(vehicle) and NetworkGetEntityIsNetworked(vehicle)
        and not IsEntityDead(vehicle) and GetPedInVehicleSeat(vehicle, -1) == 0
        and GetEntitySpeed(vehicle) <= 0.5 and #(GetEntityCoords(vehicle) - R.position(p)) <= Config.VehicleRadius
end
function R.findVehicle(p)
    -- Eigen laatst gebruikte auto heeft voorrang boven een toevallig dichterbij geparkeerde auto.
    local last = GetVehiclePedIsIn(PlayerPedId(), true)
    if eligible(last, p) then return last end
    local nearest, distance = 0, Config.VehicleRadius
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if eligible(vehicle, p) then
            local d = #(GetEntityCoords(vehicle) - R.position(p))
            if d < distance then nearest, distance = vehicle, d end
        end
    end
    return nearest
end
local function control(vehicle)
    local expires = GetGameTimer() + 2000
    repeat
        if not DoesEntityExist(vehicle) then return false end
        if NetworkHasControlOfEntity(vehicle) then return true end
        NetworkRequestControlOfEntity(vehicle)
        Wait(50)
    until GetGameTimer() > expires
    return false
end
local function opValid(op)
    local p = R.points[op.id]
    if not p or R.locked or IsEntityDead(PlayerPedId()) or not DoesEntityExist(op.vehicle) then return false end
    if NetworkGetNetworkIdFromEntity(op.vehicle) ~= op.netId then return false end
    local playerRadius = R.mode(p) == 'ped' and Config.Ped.TargetDistance + 1.0 or Config.Radius
    if op.started and R.mode(p) == 'ped' then playerRadius = Config.VehicleRadius + 3.0 end
    if #(GetEntityCoords(PlayerPedId()) - R.position(p)) > playerRadius + 0.5 then return false end
    if R.mode(p) == 'ped' then
        local ped = p.pedNetId and NetworkDoesEntityExistWithNetworkId(p.pedNetId) and NetToPed(p.pedNetId)
        if not ped or IsEntityDead(ped) then return false end
        return not IsPedInAnyVehicle(PlayerPedId(), false) and eligible(op.vehicle, p)
    end
    return GetVehiclePedIsIn(PlayerPedId(), false) == op.vehicle
        and GetPedInVehicleSeat(op.vehicle, -1) == PlayerPedId()
        and GetEntitySpeed(op.vehicle) <= 0.5
        and #(GetEntityCoords(op.vehicle) - R.position(p)) <= Config.Radius + 0.5
end
function R.repair(id)
    if R.active or R.locked then return end
    local p = R.points[id]
    if not p then return end
    local vehicle
    if R.mode(p) == 'ped' then
        if IsPedInAnyVehicle(PlayerPedId(), false) then return R.notify('Stap uit en spreek de monteur aan.') end
        vehicle = R.findVehicle(p)
    else vehicle = GetVehiclePedIsIn(PlayerPedId(), false) end
    if vehicle == 0 then return R.notify('Geen stilstaande auto zonder bestuurder gevonden. Parkeer dichterbij.') end
    local op = { id = id, vehicle = vehicle, netId = NetworkGetNetworkIdFromEntity(vehicle) }
    R.active = op; hide()
    CreateThread(function()
        while R.active == op do
            if not op.payment and not opValid(op) then R.abort('Reparatie afgebroken: voertuig of speler niet meer beschikbaar.') end
            Wait(100)
        end
    end)
    local success, failure = xpcall(function()
        if not control(vehicle) or op.cancelled then return R.notify('Voertuig niet beschikbaar voor reparatie.') end
        local ok, quote = lib.callback.await('ts_repairpoints:quote', false, id, op.netId)
        if not ok then return R.notify(quote or 'Geen verbinding met de server.') end
        op.token = quote.token
        if op.cancelled then return end
        op.dialog = true
        local choice = lib.alertDialog({ header = 'Prijsopgave reparatie',
            content = ('Kenteken: **%s**\n\nReparatie: **€%s**\n\nWil je deze auto laten repareren?'):format(quote.plate or 'Onbekend', quote.price),
            centered = true, cancel = true, labels = { confirm = 'Repareren', cancel = 'Annuleren' } })
        op.dialog = false
        if choice ~= 'confirm' or op.cancelled then return end
        if not opValid(op) or not control(vehicle) then return R.notify('Voertuig niet meer beschikbaar.') end
        local started, startError = lib.callback.await('ts_repairpoints:begin', false, op.token)
        if not started then return R.notify(startError or 'Reparatie kan niet starten.') end
        if op.cancelled then return end
        op.started = true
        op.frozen = true; FreezeEntityPosition(vehicle, true)
        if R.mode(p) == 'ped' then
            lib.showTextUI('De monteur loopt naar je auto. [X] Annuleren'); op.walkUI = true
            local deadline = GetGameTimer() + Config.Ped.ApproachTimeout
            local arrived = false
            while not op.cancelled and GetGameTimer() < deadline do
                if IsControlJustReleased(0, 73) then op.cancelled = true; break end
                local current = R.points[id]
                local ped = current and current.pedNetId and NetworkDoesEntityExistWithNetworkId(current.pedNetId) and NetToPed(current.pedNetId)
                if ped and not IsEntityDead(ped) and R.workSpot
                    and #(GetEntityCoords(ped) - R.workSpot(vehicle)) <= 1.5
                    and IsEntityPlayingAnim(ped, Config.Ped.AnimationDict, Config.Ped.AnimationClip, 3) then arrived = true; break end
                Wait(0)
            end
            lib.hideTextUI(); op.walkUI = false
            if op.cancelled then return end
            if not arrived then return R.notify('De monteur kan de auto niet bereiken. Parkeer op een vrijere plek. Er is niets afgeschreven.') end
            local accepted, arrivalError = lib.callback.await('ts_repairpoints:arrived', false, op.token)
            if not accepted then return R.notify(arrivalError or 'De monteur kon niet beginnen.') end
            if op.cancelled then return end
        end
        op.progress = true
        local done = lib.progressCircle({ duration = Config.Duration, label = ('Voertuig repareren — €%s'):format(quote.price),
            position = 'bottom', canCancel = true, useWhileDead = false,
            disable = { move = true, car = true, combat = true } })
        op.progress = false
        if not done or op.cancelled then return end
        if not opValid(op) or not control(vehicle) then return R.notify('Voertuig niet meer beschikbaar. Geen betaling uitgevoerd.') end
        op.payment = true
        local paid, result = lib.callback.await('ts_repairpoints:finish', false, op.token)
        if not paid then return R.notify(result or 'Reparatie geweigerd.') end
        if not DoesEntityExist(vehicle) or NetworkGetNetworkIdFromEntity(vehicle) ~= result.netId or not NetworkHasControlOfEntity(vehicle) then
            return R.notify('Betaling verwerkt, maar voertuig niet meer beschikbaar. Neem contact op met staff.')
        end
        SetVehicleFixed(vehicle); SetVehicleDeformationFixed(vehicle)
        SetVehicleEngineHealth(vehicle, 1000.0); SetVehicleBodyHealth(vehicle, 1000.0)
        SetVehiclePetrolTankHealth(vehicle, 1000.0); SetVehicleUndriveable(vehicle, false)
        for _, tyre in ipairs({0, 1, 2, 3, 4, 5, 45, 47}) do SetVehicleTyreFixed(vehicle, tyre) end
        R.notify(('Voertuig gerepareerd voor €%s.'):format(result.price), 'success')
    end, debug.traceback)
    if op.walkUI then lib.hideTextUI() end
    if op.token then TriggerServerEvent('ts_repairpoints:cancel', op.token) end
    if op.frozen and DoesEntityExist(vehicle) then FreezeEntityPosition(vehicle, false) end
    if op.abortMessage then R.notify(op.abortMessage) end
    if not success then
        print(('[ts_repairpoints] Reparatiefout: %s'):format(failure))
        R.notify(op.payment and 'Verbinding verbroken tijdens betaling. Laat staff de boeking controleren.' or 'Reparatie mislukt. Probeer opnieuw.')
    end
    R.active = nil
end
CreateThread(function()
    while true do
        local sleep, near = 750, nil
        if not R.locked and not R.active then
            local coords, best = GetEntityCoords(PlayerPedId()), Config.Radius
            for id, p in pairs(R.points) do
                if R.mode(p) == 'marker' then
                    local pos = R.position(p)
                    local distance = #(coords - pos)
                    if distance < Config.DrawDistance then
                        sleep = 0
                        DrawMarker(1, pos.x, pos.y, pos.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, Config.Radius * 2, Config.Radius * 2, 0.25, 30, 180, 100, 110, false, false, 2, false, nil, nil, false)
                        if distance < best then best = distance; near = id end
                    end
                end
            end
        end
        if near and IsPedInAnyVehicle(PlayerPedId(), false) then
            if not shown then lib.showTextUI('[E] Reparatieprijs opvragen'); shown = true end
            if IsControlJustReleased(0, 38) then R.repair(near) end
        else hide() end
        Wait(sleep)
    end
end)
AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    hide(); R.abort()
    if R.active and R.active.walkUI then lib.hideTextUI() end
    if R.active and R.active.frozen and DoesEntityExist(R.active.vehicle) then FreezeEntityPosition(R.active.vehicle, false) end
    for _, b in ipairs(blips) do RemoveBlip(b) end
end)
