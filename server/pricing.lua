local function finite(n) return type(n) == 'number' and n == n and math.abs(n) < math.huge end
assert(finite(Config.Price) and Config.Price >= 0 and Config.Price % 1 == 0, 'Ongeldige maximumprijs')
assert(finite(Config.MinPrice) and Config.MinPrice >= 0 and Config.MinPrice <= Config.Price and Config.MinPrice % 1 == 0, 'Ongeldige minimumprijs')
assert(finite(Config.DamageWeights.engine) and Config.DamageWeights.engine >= 0, 'Ongeldig motorgewicht')
assert(finite(Config.DamageWeights.body) and Config.DamageWeights.body >= 0, 'Ongeldig carrosseriegewicht')
assert(Config.DamageWeights.engine + Config.DamageWeights.body > 0, 'Schadegewichten mogen niet beide nul zijn')
assert(Config.Duration >= 1000 and Config.StatusInterval >= 250 and Config.QuoteLifetime >= 5, 'Ongeldige tijden')
assert(Config.VehicleRadius > 0 and Config.Ped.TargetDistance > 0, 'Ongeldig bereik')
assert(Config.Interaction == 'ped' or Config.Interaction == 'marker', 'Ongeldige Interaction')
assert(Config.DutyMode == 'auto' or Config.DutyMode == 'job' or Config.DutyMode == 'custom', 'Ongeldige DutyMode')
function RepairPriceFromHealth(engine, body)
    if not finite(engine) or not finite(body) then return nil end
    local e = 1.0 - math.min(1000.0, math.max(0.0, engine)) / 1000.0
    local b = 1.0 - math.min(1000.0, math.max(0.0, body)) / 1000.0
    local w = Config.DamageWeights
    local damage = (e * w.engine + b * w.body) / (w.engine + w.body)
    return math.min(Config.Price, math.max(Config.MinPrice, math.ceil(Config.Price * damage)))
end
function RepairVehicleQuote(vehicle)
    local ok, engine, body = pcall(function()
        return GetVehicleEngineHealth(vehicle), GetVehicleBodyHealth(vehicle)
    end)
    if not ok then return nil, 'Voertuigschade niet beschikbaar. Controleer je server-artifactversie.' end
    local price = RepairPriceFromHealth(engine, body)
    if not price then return nil, 'Ongeldige schadegegevens.' end
    return { price = price, engine = engine, body = body }
end
function RepairDamageMatches(quote, vehicle)
    local current = RepairVehicleQuote(vehicle)
    return current and math.abs(current.engine - quote.engine) <= Config.DamageTolerance
        and math.abs(current.body - quote.body) <= Config.DamageTolerance
end
