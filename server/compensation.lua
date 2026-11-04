-- Persistente inning, één dossier per overlijden; nooit een geldbedrag uit de client.
local ESX = exports.es_extended:getSharedObject()
local resource = GetCurrentResourceName()
local ledger = { nextId = 1, records = {} }
local raw = LoadResourceFile(resource, 'data/compensation.json')
if raw then
    local ok, data = pcall(json.decode, raw)
    assert(ok and type(data) == 'table' and type(data.records) == 'table' and type(data.nextId) == 'number', 'Beschadigd data/compensation.json; herstel dit bestand.')
    ledger = data
end
assert(Config.PedDeath.Compensation > 0 and Config.PedDeath.Compensation % 1 == 0, 'Ongeldige schadevergoeding')
assert(Config.PedDeath.CollectionInterval >= 5 and Config.PedDeath.RespawnSeconds >= 30, 'Ongeldige PedDeath-tijden')
for _, r in ipairs(ledger.records) do
    if r.status == 'debit_inflight' or r.status == 'credit_inflight' then
        r.status = 'review'; r.reason = 'Server gestopt tijdens betaling; boekingen controleren.'
        print(('[ts_repairpoints] DOSSIER %s vereist controle na herstart.'):format(r.id))
    end
end
local function save()
    local ok = SaveResourceFile(resource, 'data/compensation.json', json.encode(ledger, { indent = true }), -1)
    if not ok then print('[ts_repairpoints] Kan compensation.json niet opslaan. Geen nieuwe geldmutaties uitgevoerd.') end
    return ok
end
local function call(name, ...)
    local ok, result = pcall(function(...) local b = exports.ts_bridge; return b[name](b, ...) end, ...)
    if not ok then return { ok = false, uncertain = true, code = tostring(result) } end
    return result
end
local function identifier(xp)
    return xp and (xp.identifier or (xp.getIdentifier and xp.getIdentifier()))
end
local function findPlayer(wanted)
    for _, xp in pairs(ESX.GetExtendedPlayers()) do
        if identifier(xp) == wanted then return tonumber(xp.source) end
    end
end
local function review(r, phase, result)
    r.status, r.reason = 'review', phase
    save()
    print(('[ts_repairpoints] DOSSIER %s: controleer %s (%s)'):format(r.id, phase, json.encode(result)))
end
local function collect(r)
    if GetResourceState('ts_bridge') ~= 'started' then return end
    if r.status == 'pending' then
        local src = findPlayer(r.identifier)
        if not src then return end
        local balance, society = call('GetMoney', src, r.account), call('GetSocietyBalance', r.society)
        if type(balance) ~= 'number' or balance < r.amount or type(society) ~= 'number' then return end
        r.status = 'debit_inflight'
        if not save() then r.status = 'pending'; return end
        local result = call('RemoveMoney', src, r.account, r.amount, 'Schadevergoeding reparateur #' .. r.id)
        if type(result) ~= 'table' or result.ok ~= true then
            if type(result) == 'table' and result.uncertain == false then r.status = 'pending'; save()
            else review(r, 'afschrijving', result) end
            return
        end
        r.status = 'credit_pending'
        if not save() then r.status = 'review'; return end
        TriggerClientEvent('ox_lib:notify', src, { title = 'Schadevergoeding', type = 'error',
            description = ('€%s afgeschreven wegens het doden van een reparateur. Dossier %s.'):format(r.amount, r.id) })
    end
    if r.status == 'credit_pending' then
        r.status = 'credit_inflight'
        if not save() then r.status = 'credit_pending'; return end
        local result = call('AddSocietyMoney', r.society, r.amount)
        if type(result) == 'table' and result.ok == true then
            r.status, r.paidAt = 'paid', os.time()
            if not save() then r.status = 'review' end
        elseif type(result) == 'table' and result.uncertain == false then
            r.status = 'credit_pending'; save() -- reeds geïnd, alleen bijschrijving opnieuw proberen
        else review(r, 'societybijschrijving', result) end
    end
end
local processing = {}
local function attempt(r)
    if processing[r.id] then return end
    processing[r.id] = true
    local ok, err = pcall(collect, r)
    processing[r.id] = nil
    if not ok then review(r, 'onverwachte fout', tostring(err)) end
end
function RepairCreateCompensation(attackerIdentifier, pointId)
    if type(attackerIdentifier) ~= 'string' or attackerIdentifier == '' then return end
    local r = { id = ledger.nextId, identifier = attackerIdentifier, point = pointId,
        amount = Config.PedDeath.Compensation, account = Config.PedDeath.Account,
        society = Config.PedDeath.Society, status = 'pending', createdAt = os.time() }
    ledger.nextId = ledger.nextId + 1
    ledger.records[#ledger.records + 1] = r
    if not save() then return end
    local src = findPlayer(attackerIdentifier)
    if src then TriggerClientEvent('ox_lib:notify', src, { title = 'Schadevergoeding', type = 'error',
        description = ('Je bent €%s verschuldigd aan het politiefonds wegens het doden van een reparateur. Dit wordt automatisch geïnd zodra je saldo toereikend is.'):format(r.amount) }) end
    attempt(r)
end
CreateThread(function()
    while true do
        Wait(Config.PedDeath.CollectionInterval * 1000)
        for _, r in ipairs(ledger.records) do
            if r.status == 'pending' or r.status == 'credit_pending' then attempt(r) end
        end
    end
end)
