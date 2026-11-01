assert(type(Config.Price) == 'number' and Config.Price >= 0 and Config.Price % 1 == 0, 'Ongeldige prijs')
assert(Config.Duration >= 1000, 'Reparatieduur moet minstens 1000 ms zijn')
assert(Config.DutyMode == 'auto' or Config.DutyMode == 'job' or Config.DutyMode == 'custom', 'Ongeldige DutyMode')
local blocked = {}
local function call(name, ...)
    local ok, result = pcall(function(...) local bridge = exports.ts_bridge; return bridge[name](bridge, ...) end, ...)
    if not ok then return { ok = false, uncertain = true, code = tostring(result) } end
    return result
end
function RepairPaymentReady(src)
    if blocked[src] then return false, 'Betaling vereist controle door een beheerder.' end
    if Config.Price == 0 then return true end
    if GetResourceState('ts_bridge') ~= 'started' then return false, 'Betalingssysteem niet beschikbaar.' end
    local balance = call('GetMoney', src, Config.Account)
    local society = call('GetSocietyBalance', Config.Society)
    if type(balance) ~= 'number' or type(society) ~= 'number' then return false, 'Bank- of societyrekening niet beschikbaar.' end
    if balance < Config.Price then return false, 'Je hebt onvoldoende geld.' end
    return true
end
local function incident(src, phase, result)
    blocked[src] = true
    print(('[ts_repairpoints] BETALING CONTROLEREN speler=%s society=%s bedrag=%s fase=%s resultaat=%s'):format(src, Config.Society, Config.Price, phase, json.encode(result)))
    return false, 'Betaling kon niet worden bevestigd. Neem contact op met een beheerder.'
end
function RepairPayment(src)
    local ready, reason = RepairPaymentReady(src)
    if not ready then return false, reason end
    if Config.Price == 0 then return true end
    local debit = call('RemoveMoney', src, Config.Account, Config.Price, 'Reparatiepunt')
    if type(debit) ~= 'table' or debit.ok ~= true then
        if type(debit) ~= 'table' or debit.uncertain ~= false then return incident(src, 'afschrijving', debit) end
        return false, 'Afschrijving geweigerd; probeer later opnieuw.'
    end
    local credit = call('AddSocietyMoney', Config.Society, Config.Price)
    if type(credit) == 'table' and credit.ok == true then return true end
    -- Alleen terugbetalen als vaststaat dat de society NIET is bijgeschreven.
    if type(credit) == 'table' and credit.uncertain == false then
        local refund = call('AddMoney', src, Config.Account, Config.Price, 'Terugbetaling reparatiepunt')
        if type(refund) == 'table' and refund.ok == true then return false, 'Societybetaling mislukt. Je geld is teruggestort.' end
        return incident(src, 'terugbetaling', refund)
    end
    return incident(src, 'societybijschrijving', credit)
end
AddEventHandler('playerDropped', function() blocked[source] = nil end)
