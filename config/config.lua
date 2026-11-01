Config = {}
Config.Version = '1.0.0'
Config.Price = 5000 -- 0 = gratis
Config.Account = 'bank' -- bank of cash (via ts_bridge)
Config.Society = 'society_mechanic' -- bestaande mechanic-society
Config.Duration = 10000 -- milliseconden
Config.Radius = 4.0
Config.DrawDistance = 25.0
Config.StatusInterval = 2000
Config.Cooldown = 30 -- seconden per speler
Config.Blips = true
Config.AdminGroups = { admin = true, owner = true, superadmin = true, god = true }
Config.MechanicJobs = { mechanic = true } -- exacte database-jobnamen
Config.DutyMode = 'auto' -- auto, job, custom; uitleg in README
Config.Points = {
    -- Vaste punten (optioneel); gebruik unieke namen die niet met placed_ beginnen.
    -- { id = 'sandy', label = 'Reparatie Sandy', coords = { x = 1177.0, y = 2640.0, z = 37.8 } },
}
