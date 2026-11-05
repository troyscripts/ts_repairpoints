local function call(name, ...)
    local ok, result = pcall(function(...) local bridge = exports.ts_bridge; return bridge[name](bridge, ...) end, ...)
    if not ok then return { ok = false, uncertain = true, code = tostring(result) } end
    return result
end
function RepairPaymentReady(src, amount)
    if type(amount) ~= 'number' or amount ~= amount or amount < 0 or amount > Config.Price or amount % 1 ~= 0 then return false, 'Ongeldig bedrag.' end
    if amount == 0 then return true end
    if GetResourceState('ts_bridge') ~= 'started' then return false, 'Betalingssysteem niet beschikbaar.' end
    local balance = call('GetMoney', src, Config.Account)
    local society = call('GetSocietyBalance', Config.Society)
    if type(balance) ~= 'number' or type(society) ~= 'number' then return false, 'Bank- of societyrekening niet beschikbaar.' end
    if balance < amount then return false, 'Je hebt onvoldoende geld.' end
    return true
end
local function incident(src, amount, phase, result)
    print(('[ts_repairpoints] BETALING CONTROLEREN speler=%s society=%s bedrag=%s fase=%s resultaat=%s'):format(src, Config.Society, amount, phase, json.encode(result)))
    return false, 'Betaling kon niet worden bevestigd. Neem contact op met een beheerder.', true
end
function RepairPayment(src, amount, dossier)
    local ready, reason = RepairPaymentReady(src, amount)
    if not ready then return false, reason end
    if amount == 0 then return true end
    if not RepairSettlementSamePlayer(src, dossier) then return false, 'Speler niet meer beschikbaar.' end
    local debit = call('RemoveMoney', src, Config.Account, amount, 'Reparatiepunt')
    if type(debit) ~= 'table' or debit.ok ~= true then
        if type(debit) ~= 'table' or debit.uncertain ~= false then return incident(src, amount, 'afschrijving', debit) end
        return false, 'Afschrijving geweigerd; probeer later opnieuw.'
    end
    local credit = call('AddSocietyMoney', Config.Society, amount)
    if type(credit) == 'table' and credit.ok == true then return true end
    -- Alleen terugbetalen als vaststaat dat de society NIET is bijgeschreven.
    if type(credit) == 'table' and credit.uncertain == false then
        if not RepairSettlementSamePlayer(src, dossier) then return incident(src, amount, 'ontvanger terugbetaling offline', {}) end
        local refund = call('AddMoney', src, Config.Account, amount, 'Terugbetaling reparatiepunt')
        if type(refund) == 'table' and refund.ok == true then return false, 'Societybetaling mislukt. Je geld is teruggestort.' end
        return incident(src, amount, 'terugbetaling', refund)
    end
    return incident(src, amount, 'societybijschrijving', credit)
end
