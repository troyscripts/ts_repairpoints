# Electron AntiCheat: webhookafbeeldingen

Gebruik je Electron AntiCheat met `resourceProtection`? Zet dan voor de screenshotfunctie **het betreffende script én `screenshot-basic`** op de resource-whitelist. Loopt de screenshot via **`ts_bridge`**, voeg die resource dan ook toe.

Deze handleiding geldt voor Troy Scripts-resources die screenshots naar Discord-webhooks sturen. Electron AntiCheat is geen verplichte dependency van Troy Scripts. Zonder Electron zijn deze whitelist-stappen niet van toepassing.

## Welke resources moet je whitelisten?

| Resource | Wanneer toevoegen? |
| --- | --- |
| Het betreffende script | Elk geïnstalleerd script waarvan je de screenshotfunctie gebruikt. Gebruik de exacte resourcenaam. |
| `screenshot-basic` | Wanneer de screenshotfunctie hiervan gebruikmaakt. |
| `ts_bridge` | Wanneer het script screenshots via `ts_bridge` laat verwerken. |

## Whitelist instellen

1. Open het Electron AntiCheat-dashboard en selecteer de juiste server.
2. Ga naar de instellingen en open **Resources → Resource based protections**.
3. Zoek **`resourceProtection`** en open het **tandwiel** bij deze instelling.
4. Voeg de betrokken resources afzonderlijk toe aan de **resource-whitelist**. Gebruik de exacte mapnamen, inclusief streepjes en underscores.
5. Sla de wijzigingen op en pas ze toe. Volg een eventuele herstart- of herlaadinstructie van Electron.
6. Verbind opnieuw met de server en test de screenshotfunctie.

> Menunamen en de plaats van het tandwiel kunnen per Electron-versie of taal verschillen. Zoek bij afwijkingen naar `resourceProtection` en de bijbehorende resource-whitelist.

## Voorbeeld met ts_bridge

Gebruik je bijvoorbeeld de screenshotfunctie van `ts_hostage` via de bridge, voeg dan deze drie afzonderlijke namen toe:

```text
ts_hostage
ts_bridge
screenshot-basic
```

Vervang `ts_hostage` door de exacte naam van het script dat je installeert. Gebruik geen verzamelmap zoals `[troyscripts]` en geen algemene `ts_*`-invoer; voeg iedere betrokken resource apart toe.

Alleen `screenshot-basic` whitelisten is niet voldoende als Electron de aanroep vanuit het script of de bridge blokkeert.

## Controleren of het werkt

- [ ] `screenshot-basic`, het betreffende script en eventueel `ts_bridge` zijn gestart.
- [ ] Screenshots zijn ingeschakeld in de scriptconfiguratie en de juiste Discord-webhook is ingesteld.
- [ ] Een in-game actie uitgevoerd die volgens het script een screenshot verstuurt.
- [ ] Het bericht verschijnt **met afbeelding** in het juiste Discord-kanaal.
- [ ] Bij een fout: de Electron-detectielogs, serverconsole en F8-console van de speler gecontroleerd.

## Problemen oplossen

### Wel tekst, geen afbeelding

Controleer opnieuw alle betrokken resources op de whitelist. Als het script tekstlogging als terugval gebruikt, bewijst een tekstbericht nog niet dat de screenshot is gelukt.

### Electron meldt antiIllegalTrigger

Bij een eerdere test werd het volgende event gedetecteerd:

```text
ts_bridge:screenshot:result
```

Controleer vooral of `ts_bridge` onder `resourceProtection` is gewhitelist en de wijziging is toegepast. Blijft dit event geblokkeerd, laat Electron-support de specifieke detectie controleren. **Schakel `antiIllegalTrigger` niet volledig uit.**

### Geen Electron-detectie, maar nog steeds geen afbeelding

Controleer de screenshot- en uploadfout in de logs. Een onjuiste webhook, een uploadfout of een verbindingsprobleem kan ook de oorzaak zijn. Whitelisting lost zulke fouten niet automatisch op.

### Is een speler- of admin-whitelist voldoende?

Nee. Deze handleiding gaat over de **resource-whitelist**. Een speler- of admin-whitelist vervangt deze instelling niet. Er hoeft voor deze procedure geen Electron-export aan het script te worden toegevoegd.

## Achtergrond en bronnen

Bij Gemert RP werkten de webhookfoto's na de eerdere whitelist-aanpassingen weer. Deze handleiding combineert die praktijkstappen met Electron's advies om conflicterende scripts onder `resourceProtection` te whitelisten.

- [Electron: Script Errors](https://docs.electron-services.com/troubleshooting/script-errors)
- [Electron: Configuration Tips](https://docs.electron-services.com/advanced/tips-best-configuration)

Laatst gecontroleerd: 6 november 2026.
