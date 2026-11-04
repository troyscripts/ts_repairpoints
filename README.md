# ts_repairpoints — 1.1.0
Reparatiepunten voor ESX met een optionele monteur-ped, ox_target, schadeafhankelijke prijzen en societybetalingen via ts_bridge. Nederlandse bediening.

## Installeren / bijwerken
1. Bewaar je bestaande `data/points.json` en, bij volgende updates, `data/compensation.json`. Deze bestanden worden bewust niet als lege bestanden meegeleverd.
2. Vervang de scriptbestanden en neem jouw jobnamen, society, dienstkoppeling en vaste locaties over in de nieuwe config. Configversie: 1.1.0.
3. Vereist: OneSync, es_extended, ox_lib, ts_bridge en voor ped-punten ox_target. Start banking en esx_addonaccount vóór ts_bridge. Gebruik een actueel FiveM-serverartifact met server-side CreatePed, GetVehicleEngineHealth, GetVehicleBodyHealth en GetPedSourceOfDeath.
4. Start na deze dependencies: `ensure ts_repairpoints`. Bij uitsluitend marker-punten is ox_target niet nodig.

Er zijn geen actieve voorbeeldpunten en geen SQL-wijzigingen. `society_mechanic` en `society_police` moeten bestaande, bereikbare societyrekeningen zijn. De gecontroleerde ts_bridge werkt voor societies met esx_addonaccount. De weergave in Apex/baasmenu's hangt af van jullie bestaande banksynchronisatie.

## Ped of cirkel kiezen
```lua
Config.Interaction = 'ped' -- standaard: monteur met ox_target
-- Config.Interaction = 'marker' -- cirkel inrijden en E gebruiken
Config.Ped.Model = 's_m_y_xmech_02'
```
De ped is een extra optie; de originele cirkel blijft beschikbaar. Elk vast punt kan afzonderlijk `interaction = 'ped'` of `interaction = 'marker'` hebben. Zonder die eigenschap geldt de globale instelling. Bestaande in-game punten blijven werken en volgen de globale keuze.

In ped-modus: parkeer je auto binnen Config.VehicleRadius (standaard 8 meter), stap uit en spreek de ped aan via ox_target. Je laatste voertuig heeft voorrang als het geschikt is; anders wordt de dichtstbijzijnde stilstaande auto zonder bestuurder gekozen. Controleer het kenteken in de prijsopgave voordat je bevestigt. Na bevestiging loopt de monteur naar de voorkant van de auto en voert hij daar een reparatieanimatie uit. De reparatietimer start pas wanneer hij daar staat; daarna volgt de betaling. Vervolgens loopt hij terug naar zijn werkplek. Eén monteur helpt maar één klant tegelijk. Blijf tijdens het werk in de buurt; je mag hem naar de auto volgen. Er is geen eigendomseis: ook een geleende of NPC-auto kan worden gerepareerd. Een auto met bestuurder is niet beschikbaar.

In marker-modus: rijd de cirkel in, blijf als bestuurder zitten, zet de auto stil en druk E. Beide modi tonen vooraf de prijs en gebruiken dezelfde societybetaling en dienstcontrole.

## Punten beheren
Bevoegd: ESX admin, owner, superadmin, god of ACE `ts_repairpoints.admin`.

- `/reparatiepunt plaatsen [naam]`: sla je positie en kijkrichting op. Voor een ped: plaats te voet op een vrije, beloopbare plek naast parkeerruimte.
- `/reparatiepunt lijst`: toon de IDs en namen.
- `/reparatiepunt vertrek [id]`: sla je huidige positie op als vertrekplek van deze ped, binnen 100 meter van zijn werkplek.
- `/reparatiepunt verwijderen [id]`: verwijder een in-game punt.

Optionele ACE: `add_ace group.admin ts_repairpoints.admin allow`.
Vaste punten configureer je in Config.Points, inclusief optionele `heading`, `leaveCoords`, `pedModel` en `interaction`. Vaste punten wijzig je in de config. Na configwijzigingen herstarten. De datamap moet schrijfbaar zijn.

## Naar de auto lopen en repareren
Parkeer met vrije loopruimte vóór de auto. Config.Ped.ApproachTimeout staat standaard op 30000 ms. Lukt het niet om de auto binnen die tijd te bereiken, dan stopt de aanvraag zonder afschrijving. Tijdens het lopen kun je met X annuleren. Na afronding/annulering loopt hij terug; bij een mechanic in dienst naar zijn vertrekplek. De positie en animatie zijn zichtbaar voor andere spelers via de gedeelde netwerkped.

De animatie is instelbaar via Config.Ped.AnimationDict en AnimationClip (standaard mini@repair / fixing_a_ped). Config.Ped.WorkDistance is de maximale serverafstand van monteur tot voertuig. De cirkelmodus gebruikt geen ped en behoudt de normale reparatietimer.

## Weglopen als de garage open is
Zodra een monteur in dienst is, blokkeren reparaties. Een lopende aanvraag wordt afgebroken vóór betaling. De ped loopt rustig naar zijn ingestelde vertrekplek; zonder ingestelde vertrekplek loopt hij standaard 20 meter in zijn kijkrichting. Hij blijft daar bestaan en loopt terug wanneer er geen monteur meer in dienst is. Tijdens teruglopen kun je pas weer repareren wanneer hij bij zijn werkplek is.

De ped wordt hierbij niet verwijderd, opnieuw gespawned of geteleporteerd. Het is één gedeelde netwerkped per punt. Normale FiveM-streaming bepaalt of spelers op grote afstand hem zien. Kies bereikbare vertrekplekken: de GTA-navmesh kan niet door muren/gesloten deuren lopen. Bij een geblokkeerde route probeert hij opnieuw zonder te teleporteren.

Marker-punten verbergen de cirkel als de garage open is. Blips verdwijnen eveneens. Dienststatus wordt standaard elke 2 seconden ververst; aanvragen controleren ook rechtstreeks op de server.

## Dynamische reparatieprijs
```lua
Config.Price = 5000 -- maximum
Config.MinPrice = 250
Config.DamageWeights = { engine = 0.6, body = 0.4 }
Config.Account = 'bank' -- of cash
Config.Society = 'society_mechanic'
```
De server leest de gesynchroniseerde GTA-motor- en carrosseriehealth uit. Beide waarden worden voor de berekening begrensd op 0–1000. De schadepercentages tellen standaard voor 60% en 40% mee. De gewogen schade maal het maximum wordt naar boven afgerond, met het ingestelde minimum als ondergrens.

| Motor / carrosserie | Prijs bij standaardconfig |
| --- | ---: |
| Beide 1000 (ook alleen cosmetisch/banden) | €250 minimumtarief |
| Beide 900 | €500 |
| Beide 500 | €2.500 |
| Motor 0, carrosserie 1000 | €3.000 |
| Beide 0 of lager | €5.000 |

Banden, ruiten en visuele vervorming tellen niet afzonderlijk mee in de prijs; daarvoor geldt ten minste het minimumtarief. De reparatie herstelt GTA-motor, carrosserie, tank, banden en vervorming. Tuning, kenteken, kleuren en brandstofhoeveelheid worden niet aangepast. Afzonderlijke Sky-slijtage/onderdelenadministratie valt hier niet onder.

De volledige offerteprijs gaat naar society_mechanic. De speler bevestigt eerst het kenteken en de prijs. Alleen de op de server opgeslagen prijs wordt geïnd. Als de schade tijdens de aanvraag merkbaar verandert, moet een nieuwe prijsopgave worden aangevraagd. Een offerte verloopt na 30 seconden. Eén aanvraag per speler en voertuig; cooldown na succes. Geen kosten bij normaal annuleren. Voor gratis reparaties stel je zowel Price als MinPrice op 0.

## Ped vermoorden: politie en schadevergoeding
De netwerkped is kwetsbaar, ook tijdens het weg- of teruglopen. Wanneer de server zijn dood vaststelt:

1. Lopende reparaties bij die ped worden geblokkeerd/afgebroken.
2. Politie krijgt via ts_bridge een melding met de locatie, inclusief de bestaande blip/waypointbediening van de bridge. Hiervoor worden de ingestelde PoliceJobs gebruikt.
3. De server bepaalt de dader via de gesynchroniseerde doodsoorzaak. Bij een voertuig is dat de bestuurder. Een recente als dodelijk gemelde wapentreffer is het noodpad; die telt pas nadat de server de dood heeft vastgesteld. Een cliënt kan geen willekeurig dader-ID of boetebedrag insturen.
4. De dader betaalt automatisch €10.000 aan society_police. Dit staat los van de reparatieprijs en reparatie-society.

```lua
Config.PedDeath.Compensation = 10000
Config.PedDeath.Account = 'bank'
Config.PedDeath.Society = 'society_police'
Config.PedDeath.PoliceJobs = { police = true }
Config.PedDeath.RespawnSeconds = 600
Config.PedDeath.CollectionInterval = 30
```

Bij onvoldoende banksaldo blijft het volledige bedrag als schuld bewaard; er is geen gedeeltelijke afschrijving of negatief saldo. Elke 30 seconden probeert het script opnieuw. De schuld blijft na reconnect en resource/serverherstart bestaan, gekoppeld aan het ESX-karakteridentifier. Er is één dossier per overlijden, zonder staff-uitzondering. Een nieuwe moord levert een nieuw dossier op. Na standaard 10 minuten wordt het lichaam verwijderd en komt er een nieuwe monteur. Een vermoorde ped komt niet eerder terug door een wisseling van dienststatus.

Bij een ongeval zonder herkenbare speler als dader volgt wel een politiemelding, maar wordt geen willekeurige speler belast. De server schrijft een diagnostische melding. Een tijdig gesynchroniseerde doodsoorzaak is nodig; dit is geen anticheat en client/netwerksynchronisatie kan geen absolute dadergarantie bieden. Als niemand met een ingestelde politiejob online is, is er geen ontvanger voor de melding.

## Dienstcontrole / Sky
- `Config.DutyMode = 'auto'`: controleert de exacte mechanic-jobnaam en ESX job.onDuty. Bij false telt de monteur niet mee; ontbreekt de status, dan telt de job als in dienst.
- `job`: de ingestelde jobnaam betekent in dienst; gebruik dit wanneer uitdienst een andere jobnaam krijgt. Voeg off-jobs niet aan Config.MechanicJobs toe.
- `custom`: sluit in config/server.lua de echte server-API van een apart dienstsysteem aan. Een ontbrekende/defecte customkoppeling sluit de punten wanneer een mechanic online is.

Er is geen aangenomen Sky-export gebruikt. Als jullie Sky-versie uitsluitend een interne dienststatus bijhoudt, moet custom daarop worden aangesloten. Controleer in- en uitdienst op de testserver.

## Versiechecker
Config.UpdateCheck staat standaard aan voor `troyscripts/ts_repairpoints`, branch `main`. De checker leest uitsluitend de version-regel uit het publieke fxmanifest.lua op GitHub. Geen extra version.json nodig, geen code-uitvoering of automatische installatie. Controle bij opstart en standaard elke 6 uur (IntervalHours = 0: alleen opstart). HTTP-fouten/time-outs stoppen de resource niet.

Wanneer deze lokale 1.1.0 nog niet op GitHub staat, meldt de checker terecht dat lokaal nieuwer is dan online. Zodra je de update uploadt naar main, gebruikt de checker dat nieuwe manifest. Deze zip publiceert zichzelf niet op GitHub.

## Betalingsherstel en gegevens bewaren
Reparatiebetalingen gebruiken de gecontroleerde ts_bridge-resultaten `{ ok, uncertain }`. Bij een bevestigde mislukte mechanic-bijschrijving wordt terugbetaling geprobeerd. Onzekere uitkomsten stoppen automatische herhaling en geven BETALING CONTROLEREN in de console.

Schadevergoedingen staan in `data/compensation.json`. `pending` wacht op saldo/beschikbare rekening; `credit_pending` is al geïnd en wacht alleen op bijschrijving. `paid` is afgerond. `review` vereist dat staff de bank- en societyboekingen controleert; er vindt dan geen automatische tweede afschrijving plaats. Ook een crash tijdens een geldmutatie wordt bij herstart voor controle gemarkeerd. Betaalde dossiers blijven als administratie bewaard.

Verwijder of overschrijf compensation.json niet bij updates: daardoor zouden schulden en de controlehistorie verloren gaan. Bewaar eveneens points.json. Er is geen automatische database-atoomtransactie over speler en society; bij crashes/onzekere bridge-uitkomsten kan handmatige afhandeling nodig zijn. Verander dossierstatussen pas na controle van de echte boekingen. Bij een verdwenen voertuig/disconnect direct na een geslaagde reparatiebetaling kan staffherstel nodig zijn.

## Validatie
Lua 5.4-syntax en gesimuleerde scenario's gecontroleerd voor prijsgrenzen, societyboekingen, offerteverloop, beide interacties, dienstwisselingen, voertuigslots, pedbeweging/eigenaarmigratie, moord/aanrijding, dubbele doodmeldingen, schuldinning, herstart en versiecheckerfouten. Geen live FiveM-test uitgevoerd.

Test vóór livegebruik: beide interacties; dichtbij/te ver geparkeerde auto; offerte annuleren; schadeprijs en mechanic-saldo; mechanic in/uit dienst tijdens reparatie; vertrekroute; moord en aanrijding met twee spelers; precies één politiebericht en €10.000 bijschrijving; onvoldoende saldo gevolgd door reconnect/herstart; respawn; behoud van data bij update.
