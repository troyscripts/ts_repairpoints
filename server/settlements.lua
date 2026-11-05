-- Bewaar betaling en aflevering apart. Een clientbevestiging veroorzaakt nooit geldmutaties.
local ESX = exports.es_extended:getSharedObject()
local resource = GetCurrentResourceName()
local ledger = { nextId = 1, records = {} }
local active, runtime, byId = {}, {}, {}
local raw = LoadResourceFile(resource, 'data/repairs.json')
if raw then
    local ok, data = pcall(json.decode, raw)
    assert(ok and type(data) == 'table' and type(data.records) == 'table'
        and type(data.nextId) == 'number', 'Beschadigd data/repairs.json; herstel dit bestand.')
    ledger = data
end
local function save()
    return SaveResourceFile(resource, 'data/repairs.json', json.encode(ledger, { indent = true }), -1)
end
local function identity(src)
    local xp = ESX.GetPlayerFromId(src)
    return xp and xp.identifier
end
local function unresolved(r) return r.status ~= 'complete' and r.status ~= 'cancelled' and r.status ~= 'resolved' end
for _, r in ipairs(ledger.records) do
    byId[r.id] = r
    if unresolved(r) then
        r.status, r.reason = 'review', 'Resource herstart; controleer betaling en voertuig.'
        active[r.identifier] = r
        print(('[ts_repairpoints] REPARATIEDOSSIER %s vereist controle.'):format(r.id))
    end
end
function RepairSettlementPending(src)
    return active[identity(src)]
end
function RepairSettlementVehiclePending(vehicle)
    for _, r in pairs(active) do
        local state = runtime[r.id]
        if state and state.vehicle == vehicle then return true end
    end
    return false
end
function RepairSettlementSamePlayer(src, r) return identity(src) == r.identifier end
function RepairSettlementCreate(src, session)
    local identifier = identity(src)
    if not identifier or active[identifier] then return nil end
    local r = { id = ledger.nextId, identifier = identifier, status = 'payment',
        price = session.price, account = Config.Account, society = Config.Society,
        plate = session.plate, model = session.model, created = os.time() }
    ledger.nextId = ledger.nextId + 1
    ledger.records[#ledger.records + 1] = r
    byId[r.id] = r
    active[identifier] = r
    runtime[r.id] = { vehicle = session.vehicle, netId = session.netId,
        engine = session.engine, body = session.body }
    if not save() then
        active[identifier], runtime[r.id], byId[r.id] = nil, nil, nil
        table.remove(ledger.records)
        return nil
    end
    return r
end
function RepairSettlementResult(r, paid, message, uncertain)
    r.status = paid and 'paid' or (uncertain and 'review' or 'cancelled')
    r.reason = message
    r.expires = os.time() + 120
    if not save() then
        r.status, r.reason = 'review', 'Opslaan betaalresultaat mislukt; controleer de boekingen.'
        print(('[ts_repairpoints] REPARATIEDOSSIER %s: %s'):format(r.id, r.reason))
        return false
    end
    if not unresolved(r) then active[r.identifier], runtime[r.id] = nil, nil end
    return paid
end
local function complete(r)
    r.status, r.completed = 'complete', os.time()
    if not save() then r.status = 'paid'; return false, 'Opslaan bevestiging mislukt; probeer /reparatieherstel.' end
    active[r.identifier], runtime[r.id] = nil, nil
    return true, { complete = true, dossier = r.id }
end
local function inspect(src, r)
    if not r or r.status ~= 'paid' then return nil, 'Geen hervatbare reparatie; laat staff het reparatiedossier controleren.' end
    if os.time() > r.expires then return nil, 'Hersteltermijn verlopen; laat staff dossier ' .. r.id .. ' controleren.' end
    local state = runtime[r.id]
    local ped = GetPlayerPed(src)
    local vehicle = state and NetworkGetEntityFromNetworkId(state.netId) or 0
    if ped == 0 or vehicle == 0 or vehicle ~= state.vehicle or not DoesEntityExist(vehicle)
        or GetEntityModel(vehicle) ~= r.model or GetVehicleNumberPlateText(vehicle) ~= r.plate
        or GetEntityRoutingBucket(vehicle) ~= GetPlayerRoutingBucket(src)
        or #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > 12.0 then
        return nil, 'Ga bij hetzelfde voertuig staan; anders moet staff dossier ' .. r.id .. ' controleren.'
    end
    local quote = RepairVehicleQuote(vehicle)
    if not quote then return nil, 'Voertuigschade nog niet beschikbaar.' end
    return state, quote
end
lib.callback.register('ts_repairpoints:recover', function(src)
    local r = RepairSettlementPending(src)
    local state, quote = inspect(src, r)
    if not state then return false, quote end
    if r.dispatched and (state.engine < 999.0 or state.body < 999.0)
        and quote.engine >= 999.0 and quote.body >= 999.0 then return complete(r) end
    if math.abs(quote.engine - state.engine) > Config.DamageTolerance
        or math.abs(quote.body - state.body) > Config.DamageTolerance then
        return false, 'Schade gewijzigd; laat staff dossier ' .. r.id .. ' controleren.'
    end
    if not r.dispatched then
        r.dispatched = true
        if not save() then
            r.dispatched = nil
            return false, 'Herstelopdracht kon niet worden opgeslagen.'
        end
    end
    return true, { netId = state.netId, model = r.model, plate = r.plate, price = r.price, dossier = r.id }
end)
lib.callback.register('ts_repairpoints:confirmed', function(src, id)
    local r = byId[id]
    if r and r.identifier == identity(src) and r.status == 'complete' then return true, { complete = true, dossier = id } end
    if not r or r ~= RepairSettlementPending(src) or not r.dispatched then return false, 'Ongeldig reparatiedossier.' end
    local state, quote = inspect(src, r)
    if not state then return false, quote end
    if quote.engine < 999.0 or quote.body < 999.0 then return false, 'Reparatie nog niet door de server bevestigd.' end
    return complete(r)
end)
-- Alleen console: administratief sluiten nadat staff de echte boekingen heeft gecontroleerd.
-- Dit command schrijft zelf geen geld bij en kan geen reparatie opnieuw vrijgeven.
RegisterCommand('reparatiedossier', function(src, args)
    if src ~= 0 then return end
    if args[1] == 'lijst' then
        for _, r in ipairs(ledger.records) do
            if unresolved(r) then print(json.encode(r)) end
        end
        return
    end
    local id, reason = tonumber(args[2]), table.concat(args, ' ', 3)
    if args[1] ~= 'sluiten' or not id or #reason < 5 then
        return print('reparatiedossier lijst | sluiten [id] [reden na handmatige controle]')
    end
    for _, r in ipairs(ledger.records) do
        if r.id == id and unresolved(r) then
            if r.status == 'payment' then return print('Betaling loopt nog; wacht tot deze is afgerond.') end
            local previous = r.status
            r.status, r.resolution = 'resolved', reason
            if not save() then r.status = previous; return print('Opslaan mislukt; dossier blijft open.') end
            active[r.identifier], runtime[r.id] = nil, nil
            return print('Reparatiedossier gesloten; geen geldmutatie uitgevoerd.')
        end
    end
    print('Geen open dossier met dit ID.')
end, false)
