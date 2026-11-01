-- Alleen server-side. Voor een apart dienstsysteem: stel DutyMode = 'custom'.
-- Geef true terug wanneer deze monteur in dienst is, anders false.
-- Geen aangenomen Sky-export: sluit hier de echte server-API van jouw versie aan.
function IsRepairMechanicOnDuty(xPlayer, job)
    error('Custom dienstcontrole is nog niet ingesteld')
end
