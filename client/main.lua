local points, blips, locked, busy, shown = {}, {}, true, false, false
local function hide()
    if shown then lib.hideTextUI(); shown = false end
end
local function applyState(data, unavailable)
    points, locked = data or {}, unavailable ~= false
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
    blips = {}
    if Config.Blips and not locked then
        for _, p in pairs(points) do
            local b = AddBlipForCoord(p.coords.x, p.coords.y, p.coords.z)
            SetBlipSprite(b, 402); SetBlipColour(b, 2); SetBlipScale(b, 0.65)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING'); AddTextComponentString(p.label); EndTextCommandSetBlipName(b)
            blips[#blips + 1] = b
        end
    end
    if locked then hide() end
end
RegisterNetEvent('ts_repairpoints:sync', applyState)
CreateThread(function()
    local data, unavailable = lib.callback.await('ts_repairpoints:state', false)
    applyState(data, unavailable)
end)
local function notify(message, kind)
    lib.notify({ title = 'Reparatiepunt', description = message, type = kind or 'error' })
end
local function repair(id)
    if busy then return end
    busy = true; hide()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= PlayerPedId() or GetEntitySpeed(vehicle) > 0.5 then
        busy = false; return notify('Ga als bestuurder in je voertuig zitten en zet het stil.')
    end
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local ok, err = lib.callback.await('ts_repairpoints:begin', false, id, netId)
    if not ok then busy = false; return notify(err or 'Geen verbinding met de server.') end
    local cancelled = false
    CreateThread(function()
        while busy and not cancelled do
            if locked or not DoesEntityExist(vehicle) or GetVehiclePedIsIn(PlayerPedId(), false) ~= vehicle or IsEntityDead(PlayerPedId()) then
                cancelled = true
                if lib.progressActive() then lib.cancelProgress() end
                break
            end
            Wait(100)
        end
    end)
    local done = lib.progressCircle({ duration = Config.Duration, label = 'Voertuig repareren...', position = 'bottom', canCancel = true, useWhileDead = false, disable = { move = true, car = true, combat = true } })
    if not done or cancelled or not NetworkHasControlOfEntity(vehicle) then
        TriggerServerEvent('ts_repairpoints:cancel'); busy = false
        return notify('Reparatie afgebroken. Er is niets afgeschreven.')
    end
    local paid, result = lib.callback.await('ts_repairpoints:finish', false)
    if paid and DoesEntityExist(vehicle) and NetworkGetNetworkIdFromEntity(vehicle) == result then
        SetVehicleFixed(vehicle); SetVehicleDeformationFixed(vehicle)
        SetVehicleEngineHealth(vehicle, 1000.0); SetVehicleBodyHealth(vehicle, 1000.0)
        SetVehiclePetrolTankHealth(vehicle, 1000.0); SetVehicleUndriveable(vehicle, false)
        for _, tyre in ipairs({0, 1, 2, 3, 4, 5, 45, 47}) do SetVehicleTyreFixed(vehicle, tyre) end
        notify(('Voertuig gerepareerd voor €%s.'):format(Config.Price), 'success')
    elseif paid then
        notify('Betaling verwerkt, maar voertuig verdwenen. Neem contact op met staff.')
    else notify(result or 'Reparatie geweigerd.') end
    busy = false
end
CreateThread(function()
    while true do
        local sleep, near = 800, nil
        if not locked and not busy then
            local coords = GetEntityCoords(PlayerPedId())
            local best = Config.Radius
            for id, p in pairs(points) do
                local pos = vector3(p.coords.x, p.coords.y, p.coords.z)
                local distance = #(coords - pos)
                if distance < Config.DrawDistance then
                    sleep = 0
                    DrawMarker(1, pos.x, pos.y, pos.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, Config.Radius * 2, Config.Radius * 2, 0.25, 30, 180, 100, 110, false, false, 2, false, nil, nil, false)
                    if distance < best then best = distance; near = id end
                end
            end
        end
        if near and IsPedInAnyVehicle(PlayerPedId(), false) then
            if not shown then lib.showTextUI(('[E] Repareren — €%s'):format(Config.Price)); shown = true end
            if IsControlJustReleased(0, 38) then repair(near) end
        else hide() end
        Wait(sleep)
    end
end)
AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    hide()
    if busy and lib.progressActive() then lib.cancelProgress() end
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
end)
