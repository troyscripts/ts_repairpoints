-- Leest uitsluitend het versienummer uit het publieke manifest; voert nooit code uit.
local resource, busy = GetCurrentResourceName(), false
local function log(message) print(('^3[%s]^7 %s'):format(resource, message)) end
local function parse(value)
    if type(value) ~= 'string' then return nil end
    local a, b, c = value:match('^v?(%d+)%.(%d+)%.(%d+)$')
    if not a or #a > 6 or #b > 6 or #c > 6 then return nil end
    return { tonumber(a), tonumber(b), tonumber(c) }
end
local function check()
    local cfg = Config.UpdateCheck
    if not cfg or not cfg.Enabled or busy then return end
    local repo, branch = cfg.Repository, cfg.Branch
    if type(repo) ~= 'string' or not repo:match('^[%w_-]+/[%w_.-]+$')
        or type(branch) ~= 'string' or not branch:match('^[%w_./-]+$') then
        return log('Ongeldige versiechecker-instellingen.')
    end
    local localVersion = GetResourceMetadata(resource, 'version', 0)
    local installed = parse(localVersion)
    if not installed then return log('Ongeldig lokaal versienummer in fxmanifest.lua.') end
    busy = true
    local finished = false
    local function complete()
        if finished then return false end
        finished, busy = true, false; return true
    end
    SetTimeout(15000, function() if complete() then log('Versiecontrole verlopen; de resource blijft gewoon werken.') end end)
    local url = ('https://raw.githubusercontent.com/%s/%s/fxmanifest.lua'):format(repo, branch)
    local requested = pcall(PerformHttpRequest, url, function(status, body)
        if not complete() then return end
        if status ~= 200 then return log(('Versiecontrole niet beschikbaar (HTTP %s).'):format(tostring(status))) end
        if type(body) ~= 'string' or #body > 65536 then return log('Ongeldig antwoord bij versiecontrole.') end
        local remoteVersion
        for line in body:gmatch('[^\r\n]+') do
            remoteVersion = line:match("^%s*version%s+['\"]([%dv%.]+)['\"]")
            if remoteVersion then break end
        end
        local remote = parse(remoteVersion)
        if not remote then return log('Geen geldig versienummer in het GitHub-manifest gevonden.') end
        local comparison = 0
        for i = 1, 3 do
            if remote[i] ~= installed[i] then comparison = remote[i] > installed[i] and 1 or -1; break end
        end
        if comparison > 0 then
            log(('Update beschikbaar: %s -> %s. Download: https://github.com/%s'):format(localVersion, remoteVersion, repo))
        elseif comparison == 0 then log(('Versie %s is actueel.'):format(localVersion))
        else log(('Lokale versie %s is nieuwer dan GitHub (%s).'):format(localVersion, remoteVersion)) end
    end, 'GET', '', { ['User-Agent'] = 'TroyScripts-ts_repairpoints', ['Accept'] = 'text/plain' }, { followLocation = false })
    if not requested and complete() then log('Versiecontrole kon niet worden gestart.') end
end
CreateThread(function()
    Wait(3000)
    check()
    local hours = Config.UpdateCheck and tonumber(Config.UpdateCheck.IntervalHours) or 0
    if not hours or hours <= 0 then return end
    while true do Wait(math.max(1, hours) * 3600000); check() end
end)
