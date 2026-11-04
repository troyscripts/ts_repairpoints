Config = {}
Config.Version = '1.1.1'
Config.Interaction = 'ped' -- ped = ox_target; marker = oude cirkel met E
Config.Price = 5000 -- MAXIMUM reparatieprijs, niet langer een vast bedrag
Config.MinPrice = 250 -- minimumtarief, ook voor alleen banden/ruitenschade
Config.DamageWeights = { engine = 0.6, body = 0.4 }
Config.Account = 'bank' -- bank of cash (via ts_bridge)
Config.Society = 'society_mechanic'
Config.Duration = 10000 -- milliseconden
Config.QuoteLifetime = 30 -- seconden om de prijsopgave te bevestigen
Config.DamageTolerance = 20.0 -- max health-afwijking tussen offerte/start/afronding
Config.VehicleRadius = 8.0 -- zoekbereik auto rond de reparatieplek
Config.Radius = 4.0 -- alleen marker-modus
Config.DrawDistance = 25.0 -- alleen marker-modus
Config.StatusInterval = 2000
Config.Cooldown = 30 -- seconden, per speler EN voertuig
Config.Blips = true
Config.Ped = {
    Model = 's_m_y_xmech_02',
    TargetDistance = 2.5,
    Heading = 0.0, -- oude punten zonder opgeslagen kijkrichting
    ApproachTimeout = 30000, -- max looptijd naar de auto (ms)
    WorkDistance = 6.5, -- servercontrole: monteur bij voertuig
    AnimationDict = 'mini@repair',
    AnimationClip = 'fixing_a_ped',
    WalkSpeed = 1.0, -- rustig lopen
    DepartureMode = 'wander', -- vrij wegwandelen; point = vaste richting/afstand
    LeaveDistance = 20.0, -- afstand bij DepartureMode = point; leaveCoords krijgt voorrang
    ArrivalDistance = 1.5,
}
Config.AdminGroups = { admin = true, owner = true, superadmin = true, god = true }
Config.MechanicJobs = { mechanic = true } -- exacte database-jobnamen
Config.DutyMode = 'auto' -- auto, job, custom; uitleg in README
Config.Points = {
    -- Een punt kan interaction = 'ped' of 'marker' hebben (anders Config.Interaction).
    -- { id = 'sandy', label = 'Reparatie Sandy',
    --   coords = { x = 1177.0, y = 2640.0, z = 37.8 }, heading = 90.0,
    --   leaveCoords = { x = 1157.0, y = 2640.0, z = 37.8 } },
}
Config.UpdateCheck = {
    Enabled = true,
    Repository = 'troyscripts/ts_repairpoints',
    Branch = 'main',
    IntervalHours = 6, -- 0 = alleen bij opstarten
}
Config.PedDeath = {
    Debug = false, -- alleen voor diagnose: onbekende dader in serverconsole
    Compensation = 10000, -- schadevergoeding per gedode reparateur
    Account = 'bank', -- bank of cash; onvoldoende saldo blijft als schuld bewaard
    Society = 'society_police',
    PoliceJobs = { police = true },
    AlertSeconds = 120,
    RespawnSeconds = 600, -- na overlijden komt na 10 minuten een nieuwe monteur
    CollectionInterval = 30, -- openstaande vergoedingen opnieuw proberen (seconden)
}
