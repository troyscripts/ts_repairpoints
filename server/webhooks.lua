local ESX = exports.es_extended:getSharedObject()
local titles = { murder = 'Reparateur gedood', placed = 'Reparatiepunt geplaatst', removed = 'Reparatiepunt verwijderd' }
local colors = { murder = 15158332, placed = 3066993, removed = 15105570 }
local lastWarnings, statuses = {}, {}
local function safeReason(value)
    return tostring(value or 'Geen reden teruggegeven'):gsub('https?://%S+', '[URL verborgen]'):gsub('%c', ' '):sub(1, 400)
end
local function record(action, message, failed)
    statuses[action] = message
    if failed and GetGameTimer() - (lastWarnings[action] or -60000) >= 60000 then
        lastWarnings[action] = GetGameTimer()
        print(('[ts_repairpoints] Webhook %s: %s'):format(action, message))
    end
end
local function identity(src)
    local xp = ESX.GetPlayerFromId(src)
    return xp and (xp.identifier or (xp.getIdentifier and xp.getIdentifier()))
end
local function text(value, max)
    return tostring(value or 'Onbekend'):gsub('%c', ' '):sub(1, max or 300)
end
local function pictureSource(coords, who, radius)
    local nearest, nearestDistance, killer
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src and GetPlayerName(src) and GetPlayerRoutingBucket(src) == 0 then
            local ped = GetPlayerPed(src)
            if ped ~= 0 and DoesEntityExist(ped) then
                local c = GetEntityCoords(ped)
                local distance = #(c - vector3(coords.x, coords.y, coords.z))
                if distance <= radius then
                    if who and identity(src) == who then killer = src end
                    if not nearestDistance or distance < nearestDistance then nearest, nearestDistance = src, distance end
                end
            end
        end
    end
    return killer or nearest, killer ~= nil
end
-- Alleen vanuit servercode, geen door clients aanroepbaar logevent.
function RepairLogEvent(action, point, actor, who, deathCoords)
    local cfg = RepairWebhookConfig
    if not titles[action] then return end
    if type(cfg) ~= 'table' then record(action, 'RepairWebhookConfig ontbreekt in config/server.lua.', true); return end
    if cfg.Enabled ~= true or not cfg.Events or cfg.Events[action] ~= true then
        record(action, 'Uitgeschakeld in RepairWebhookConfig.', false); return
    end
    local ok, accepted, reason = pcall(function()
        local coords = deathCoords or point.coords
        local fields = {
            { name = 'Punt', value = text(point.label) .. '\nID: ' .. text(point.id), inline = false },
            { name = 'Locatie', value = ('%.2f, %.2f, %.2f'):format(coords.x, coords.y, coords.z), inline = false },
        }
        local photoPlayer, fromKiller = actor, false
        local photo = cfg.Photos and cfg.Photos[action] == true
        if action == 'murder' then
            local radius = math.max(1, math.min(300, tonumber(cfg.WitnessRadius) or 75))
            photoPlayer, fromKiller = pictureSource(coords, who, radius)
            fields[#fields + 1] = { name = 'Dader', value = who and text(who) or 'Onbekend / niet bevestigd', inline = false }
            fields[#fields + 1] = { name = 'Schadevergoeding', value = who
                and ('€%s naar %s aangevraagd. Incasso kan nog openstaan; dit is geen betalingsbevestiging.'):format(Config.PedDeath.Compensation, Config.PedDeath.Society)
                or 'Geen speler automatisch belast.', inline = false }
        else
            fields[#fields + 1] = { name = 'Beheerder', value = text(GetPlayerName(actor)) .. ' (ID ' .. tostring(actor) .. ')\n' .. text(identity(actor)), inline = false }
        end
        if photo then
            fields[#fields + 1] = { name = 'Fotobron', value = photoPlayer
                and (('%s — %s (ID %s). Huidig spelbeeld na de gebeurtenis.'):format(
                    action ~= 'murder' and 'Beheerder' or (fromKiller and 'Dader' or 'Speler nabij'), text(GetPlayerName(photoPlayer)), photoPlayer))
                or 'Geen geschikte speler nabij; alleen tekst.', inline = false }
        end
        return exports.ts_bridge:SendWebhook(action, nil, {
            username = 'Troy Scripts', allowed_mentions = { parse = {} },
            embeds = {{ title = titles[action], color = colors[action], fields = fields,
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'), footer = { text = 'ts_repairpoints 1.1.1' } }}
        }, { screenshot = photo and photoPlayer ~= nil, playerId = photoPlayer })
    end)
    if not ok then
        record(action, 'Aanroep mislukt: ' .. safeReason(accepted), true)
    elseif accepted ~= true then
        record(action, 'Geweigerd door bridge: ' .. safeReason(reason), true)
    else
        record(action, 'Aanvaard door bridge; aflevering controleren met ts_bridge_check.', false)
    end
end

-- Alleen lezen: geen testbericht, foto, punt of geldactie uitvoeren.
RegisterCommand('ts_repairpoints_webhookcheck', function(src)
    if src ~= 0 then return end
    local cfg = RepairWebhookConfig
    local name = GetCurrentResourceName()
    print(('[ts_repairpoints] Webhookcontrole | resource: %s | bridge: %s'):format(name, GetResourceState('ts_bridge')))
    if name ~= 'ts_repairpoints' then
        print('[ts_repairpoints] Let op: de routes in TSBridgeServer.Webhooks moeten onder de werkelijke resourcenaam staan: ' .. name)
    end
    print('[ts_repairpoints] Config aanwezig: ' .. tostring(type(cfg) == 'table') .. ' | Enabled: ' .. tostring(type(cfg) == 'table' and cfg.Enabled))
    for _, action in ipairs({ 'murder', 'placed', 'removed' }) do
        print(('[ts_repairpoints] %s | event: %s | foto: %s | laatst: %s'):format(action,
            tostring(type(cfg) == 'table' and cfg.Events and cfg.Events[action]),
            tostring(type(cfg) == 'table' and cfg.Photos and cfg.Photos[action]),
            statuses[action] or 'Geen aanvraag sinds start'))
    end
end, false)
