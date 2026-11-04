# Changelog
## 1.1.0
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
