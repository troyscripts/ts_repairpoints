# ts_repairpoints — 1.0.0
Losse reparatiepunten voor Gemert Roleplay / ESX, met Nederlandse bediening.

## Installatie
1. Plaats de map `ts_repairpoints` in je resources.
2. Vereist: OneSync, es_extended, ox_lib en ts_bridge met de exports GetMoney, RemoveMoney, AddMoney, GetSocietyBalance en AddSocietyMoney. De gebruikte bridge retourneert bij mutaties een tabel met `ok` en `uncertain`.
3. Start de banking- en society-resources vóór ts_bridge, en start daarna deze resource:

```cfg
ensure es_extended
ensure ox_lib
# Start hier je banking en esx_addonaccount, daarna:
ensure ts_bridge
ensure ts_repairpoints
```

Er worden geen bestaande resources of database-instellingen gewijzigd. De bestaande society_mechanic moet aanwezig zijn. De gecontroleerde ts_bridge gebruikt esx_addonaccount voor societies; een saldo in een ander baasmenu is afhankelijk van jullie bestaande banksynchronisatie.

## Configuratie
In `config/config.lua`:

```lua
Config.Price = 5000
Config.Account = 'bank' -- of 'cash'
Config.Society = 'society_mechanic'
Config.MechanicJobs = { mechanic = true }
Config.DutyMode = 'auto'
```

De volledige prijs gaat naar de ingestelde society, ook wanneer meerdere mechanic-jobs zijn ingesteld. Prijs 0 betekent gratis. Reparatieduur, bereik, cooldown en blips zijn instelbaar. Geen dependency op ts_keycard of ox_target.

## Punten plaatsen
Als ESX admin, owner, superadmin of god, of met ACE `ts_repairpoints.admin`:

- `/reparatiepunt plaatsen [naam]`: plaats op je huidige positie, liefst midden op een vlakke plek terwijl je in de auto zit.
- `/reparatiepunt lijst`: toon IDs en namen.
- `/reparatiepunt verwijderen [id]`: verwijder een in-game geplaatst punt.

Optionele ACE: `add_ace group.admin ts_repairpoints.admin allow`.
Punten worden opgeslagen in `data/points.json`; de map is meegeleverd. Bewaar dit bestand bij updates. Er zijn bewust geen actieve voorbeeldlocaties. Vaste punten kunnen ook in Config.Points; die verwijder je in de config. Na configwijzigingen resource herstarten.

## Dienstcontrole
- `auto`: kijkt naar de exacte mechanic-jobnaam en ESX `job.onDuty`. Bij `false` telt de monteur niet mee. Als die status ontbreekt, telt de job als in dienst.
- `job`: de ingestelde jobnaam betekent altijd in dienst. Geschikt als uitdienst een andere job is, zoals off_mechanic of off_mechanicvarianten. Voeg uitdienstjobs NIET toe aan MechanicJobs.
- `custom`: gebruikt `IsRepairMechanicOnDuty` in `config/server.lua`. Deze koppeling moet eerst door een developer worden ingevuld voor een apart dienstsysteem. Een fout blokkeert punten wanneer een mechanic online is.

Dit is geen geverifieerde directe Sky-dienstintegratie: als Sky uitsluitend een interne dienststatus bijhoudt, moet custom worden aangesloten op de echte server-API van jullie Sky-versie. Controleer dit op de testserver.

Blips en markers verdwijnen bij een monteur in dienst, normaliter binnen 2 seconden. Start en afronding controleren altijd opnieuw op de server. Een lopende reparatie wordt afgebroken als een monteur in dienst gaat; er volgt dan geen betaling.

## Betaling en reparatie
Alleen de bestuurder kan stilstaand op een punt repareren. De server controleert locatie, voertuig, bestuurder, routing bucket, wachttijd en monteurstatus. Punten werken in de gewone wereld (bucket 0). Een afgeronde aanvraag is eenmalig en heeft een cooldown. Annuleren kost niets.

Na de reparatiewachttijd wordt via ts_bridge geld afgeschreven en bij de society gestort. Bij een aantoonbaar mislukte societybijschrijving wordt terugbetaling geprobeerd. Bij een onzekere uitkomst wordt niet blind nogmaals betaald: de console meldt BETALING CONTROLEREN, de reparatie stopt en verdere betalingen voor deze speler worden tot disconnect of resourceherstart geblokkeerd. Staff moet dan speler- en societyboekingen controleren. Betalingen over twee accounts zijn geen database-atoomtransactie; een servercrash tussen afschrijving en bijschrijving vereist handmatige controle.

Repareert GTA-motor, carrosserie, tank, vervorming en banden. Verandert geen tuning, kenteken, kleur of brandstofhoeveelheid. Afzonderlijke Sky-slijtage/onderdelenadministratie wordt niet aangepast. GTA-reparatie gebeurt op de client; bij disconnect/verdwijnen van het voertuig direct na betaling kan staffherstel nodig zijn. Dit is geen anticheat.

## Testen vóór livegebruik
1. Geen monteur: plaats een punt, beschadig een auto, repareer met E. Controleer bank -5000 en society +5000.
2. Monteur in dienst: punten verdwijnen en repareren is geblokkeerd. Uit dienst: punten komen terug.
3. Monteur gaat tijdens reparatie in dienst: geen reparatie en geen afschrijving.
4. Annuleer, verlaat voertuig of gebruik als passagier: geen betaling.
5. Onvoldoende saldo of ontbrekende society: geen reparatie/betaling.
6. Resource herstart: geplaatste punten blijven bestaan.
7. Controleer Sky-dienststatus en eventuele eigen voertuigslijtage apart.

Lokaal gecontroleerd: Lua-syntax en gesimuleerde server/betalingsscenario's. Niet live getest in FiveM.
