# 1.1.3 — 2026-11-05

- Targetregistratie wacht op een ingeladen netwerkped; een vroege, door ox_target genegeerde aanmelding wordt opnieuw geprobeerd.
- Registratie wordt hersteld na uit-/instreamen en ox_target-herstart.
- Beschikbaarheidsredenen worden bij selecteren gemeld; de optie verdwijnt niet stil bij een levende ped.
- Client-/serverstandplaatstolerantie gelijkgetrokken; dienst- en betaalcontroles blijven behouden.
- /reparatietargetcheck toegevoegd voor diagnose in F8. Configschema blijft 1.1.1.

# 1.1.2 — 2026-11-05
- Betaling en aflevering afzonderlijk vastgelegd in data/repairs.json.
- Voertuigcontrole na betaling opnieuw aangevraagd; server bevestigt motor/carrosserie na reparatie.
- /reparatieherstel hervat binnen twee minuten zonder tweede betaling, ook na een reconnect in dezelfde resource-runtime.
- Open/onzekere dossiers blijven bewaard en blokkeren dubbele betaling; console-afhandeling na handmatige controle.
- Terugbetaling controleert de ontvangeridentifier om hergebruik van een speler-ID af te vangen.
- Configschema blijft 1.1.1; bewaar eigen config en de volledige data-map.

# 1.1.1 — 2026-11-04

- Webhookdiagnose: geweigerde bridge-aanvragen worden niet langer stil genegeerd. Consolecontrole ts_repairpoints_webhookcheck toont schakelaars, resourcenaam en laatste resultaat per route.

- Webhooks via ts_bridge voor gedode reparateur, geslaagde plaatsing en verwijdering.
- Foto per gebeurtenis instelbaar; onbekende dader wordt niet als speler aangewezen.
- Logging na geslaagd opslaan; webhookfouten blokkeren geen spelactie of vergoeding.
- Configversie 1.1.1; eerdere doodcontrole- en wegloopfixes behouden.

# Changelog
## 1.1.0
- Vertrek hersteld: stilsta-taak direct afbreken, standaard vrij wegwandelen en bij geblokkeerde vertrekroute overschakelen op wandelen. Dienstcontrole ongewijzigd.
- Ped loopt na bevestiging naar de auto, voert een reparatieanimatie uit en loopt daarna terug. Timer start na aankomst; geblokkeerde route kost niets. Eén klant per monteur.
- Optionele gedeelde netwerkped s_m_y_xmech_02 via ox_target; standaard ped, cirkel met E blijft configureerbaar, ook per punt.
- Detectie van geparkeerde auto's en vooraf een prijsopgave met kenteken.
- Serverberekende schadeprijs, standaard minimaal 250 en maximaal 5000 euro; volledige opbrengst naar mechanic-society.
- Ped loopt rustig weg/terug bij dienstwisselingen en wordt daarbij niet verwijderd of geteleporteerd. Configureerbare vertrekplek via /reparatiepunt vertrek.
- Kwetsbare ped met politiemelding en eenmalige schadevergoeding van 10000 euro naar society_police per moord. Persistente inning bij onvoldoende saldo en gecontroleerde betalingsfases.
- Respawn van overleden ped na configureerbare wachttijd.
- Offertebevestiging, voertuigreservering, controle op veranderde schade, overlijden en dubbele afronding.
- Versiechecker voor het bestaande GitHub-manifest van troyscripts/ts_repairpoints.
- Configversie, README en documentatie bijgewerkt naar 1.1.0.

## 1.0.0
- Reparatiepunten plaatsen, bekijken en verwijderen met beheerrechten.
- Opslag van in-game punten; optionele vaste punten in config.
- ESX dienstcontrole, marker/blipstatus en Nederlandse bediening.
- Instelbare prijs, standaard 5000 euro, volledige opbrengst naar society_mechanic via ts_bridge.
- Servervalidatie, cooldown en eenmalige afronding; terugbetaling bij bevestigde mislukte societybijschrijving.

- Doodcontrole wacht op ingeladen ped en bevestigt nul-health opnieuw; tijdelijke nulwaarden veroorzaken geen doodmelding of respawn. Onbekende-daderlog alleen met Config.PedDeath.Debug = true. Versie blijft 1.1.0.
