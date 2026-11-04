-- Alleen server-side. Voor een apart dienstsysteem: stel DutyMode = 'custom'.
-- Geef true terug wanneer deze monteur in dienst is, anders false.
-- Geen aangenomen Sky-export: sluit hier de echte server-API van jouw versie aan.
function IsRepairMechanicOnDuty(xPlayer, job)
    error('Custom dienstcontrole is nog niet ingesteld')
end

-- Webhook-URLs uitsluitend in ts_bridge/config/webhook_config.lua.
-- Foto = huidig spelbeeld; geen gegarandeerde opname van het exacte moordmoment.
RepairWebhookConfig = {
    Enabled = true,
    Events = { murder = true, placed = true, removed = true },
    Photos = { murder = true, placed = true, removed = true },
    WitnessRadius = 75.0, -- fotobron bij moord moet in dezelfde instantie en nabij zijn
}
