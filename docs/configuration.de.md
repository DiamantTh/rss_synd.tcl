## Konfiguration
### Konfigurationsformate
`rss-set.tcl` enthält die Umschaltung und eine Tcl-Beispielkonfiguration. Der zentrale Schalter `settings(config-format)` entscheidet, welches Format geladen wird:
```tcl
namespace eval ::rss-synd {
    # "tcl" nutzt die Beispielkonfiguration in rss-set.tcl (Standard).
    # "toml" nutzt rss-set.toml und benötigt das Paket "tomltcl".
    set settings(config-format) tcl
    # Optional eigene Pfade setzen:
    # set settings(config-toml-file) "config/rss-set.toml"
    # set settings(config-tcl-file)  "config/rss-synd-legacy.tcl"
}
```
- **TOML**: Die Datei `rss-set.toml` enthält Abschnitte `[defaults]` und `[feeds.<name>]`. Beispiel:
  ```toml
  [defaults]
  announce-output = 3
  trigger-type = "0:2"
  [feeds.news]
  url = "https://example.tld/feed.xml"
  channels = "#news #alerts"
  ```
- **Tcl**: Setze `config-format` auf `tcl` und gib optional `config-tcl-file` an. Ohne eigenen Pfad wird die Beispielkonfiguration in `rss-set.tcl` verwendet.
Mit `tclsh tools/config-convert.tcl --from tcl --to toml --input rss-set.tcl --output converted.toml`
wandelst du eine Konfiguration um. Für die Gegenrichtung tauschst du die Formate und gibst eine Tcl-Ausgabedatei an.
Beide Richtungen benötigen `tomltcl` im Tcl-Paketsuchpfad. Konvertiere nur vertrauenswürdige Tcl-Dateien, da ihr Inhalt ausgeführt wird. Sind deine Einstellungen auf mehrere Dateien verteilt, gib die Datei mit den Feed-Definitionen an.
Die folgenden Optionen kannst du global in der Default-Konfiguration oder pro Feed festlegen. Spezifische Feed-Werte überschreiben globale Einstellungen.
### Pflichtfelder
| Option | Beschreibung | Standard | Beispiel |
| --- | --- | --- | --- |
| `url` | Adresse des RSS-/Atom-Feeds. | – | `https://example.tld/feed.xml` |
| `channels` | Liste der Kanäle für Ankündigungen und Trigger (Leerzeichen-getrennt). | `#channel` | `#news #alerts` |
| `database` | Pfad zur Datenbankdatei. | – | `./scripts/news.db` |
| `output` | Nachrichtenformat mit Cookies für Ankündigungen. | `[\002@@channel!title@@@@title@@\002] @@item!title@@@@entry!title@@@@published@@ - @@item!link@@@@entry!link!=href@@` | `[\002@@channel!title@@\002] @@item!title@@ – @@item!link@@` |
| `max-depth` | Maximale Anzahl erlaubter HTTP-Weiterleitungen. | `5` | `3` |
| `timeout` | Verbindungs-Timeout in Millisekunden. | `60000` | `45000` |
| `user-agent` | HTTP-User-Agent-Header; akzeptiert einen statischen String oder eine Tcl-Liste. Mit `user-agent-rotate = list` wird die Liste rotiert. | `rss-synd/1.0` in der Beispielkonfiguration | `rss-synd/1.0` |
| `announce-type` | Modus für automatische Ankündigungen (`0` = Channel-Message, `1` = Channel-Notice). | `0` | `1` |
| `announce-output` | Anzahl Artikel pro Ankündigung (`0` deaktiviert). | `3` | `5` |
| `trigger-type` | Ausgabeformat für Trigger `<channel>:<privmsg>` (`0/1` für Channel, `2/3` für User). | `0:2` | `1:3` |
| `trigger-output` | Anzahl Artikel pro Trigger (`0` deaktiviert). | `3` | `1` |
| `update-interval` | Abrufintervall in Minuten. | `30` | `60` |
> **Hinweis:** Das Standard-Template nutzt den Sammelplatzhalter `@@published@@`. Er prüft nacheinander `pubDate`, `published`, `updated` und `dc:date` und fügt nur bei vorhandenen Werten einen Gedankenstrich samt Datum an.
### Optionale Einstellungen
| Option | Beschreibung | Standard | Beispiel |
| --- | --- | --- | --- |
| `https-allow-legacy` | Erlaubt TLS 1.0/1.1 als Fallback (unsicher). | `0` | `1` |
| `log-mode` | Logging-Strategie für die Eggdrop-Konsole. `immediate` schreibt Meldungen sofort, `buffered` sammelt sie und fasst sie zusammen. | `immediate` | `buffered` |
| `log-interval` | Minuten bis zur Ausgabe einer zusammengefassten Log-Nachricht, wenn `log-mode` auf `buffered` steht. | `5` | `10` |
| `debug-mode` | Aktiviert Diagnosemeldungen für TLS (`tls`), HTTP-Anfragen (`http`) und Weiterleitungen (`redirect`). Akzeptiert durch Kommata oder Leerzeichen getrennte Werte oder `all`. | *(leer)* | `tls,redirect` |
| `user-agent-rotate` | Rotationsstrategie für den User-Agent: `list` aktiviert das eingebaute Round-Robin, alternativ kann der Name einer Prozedur angegeben werden, die den nächsten Eintrag liefert. Der Aufruf erhält Feed-Namen und aktuelle Einstellungen und darf einen String oder ein Dict mit `user-agent` plus Zusatzwerten zurückgeben. | `list` | `list` / `::mein::ua::next` |
| `trigger` | Öffentlicher Triggertext; `@@feedid@@` wird durch die Feed-ID ersetzt. | `!rss @@feedid@@` | `!news @@feedid@@` |
| `evaluate-tcl` | Führt Ausgaben vor dem Senden als Tcl aus. | `0` | `1` |
| `enable-gzip` | Aktiviert Gzip-Dekomprimierung für Feeds. | `0` | `1` |
| `remove-empty` | Entfernt leere Cookies aus der Ausgabe. | `1` | `0` |
| `output-order` | Reihenfolge der Artikel (`0` = älteste→neueste, `1` = neueste→älteste). | `0` | `1` |
| `charset` | Zielzeichensatz für Nachrichten. | Systemstandard | `utf-8` |
| `feedencoding` | Erzwingt einen Zeichensatz beim Einlesen des Feeds. | – | `cp1251` |
### User-Agent-Rotation
Das Skript enthält intern eine Auswahl von Browser-Kennungen. Die mitgelieferte Beispielkonfiguration verwendet `rss-synd/1.0`. Setze `user-agent` auf eine Tcl-Liste und `user-agent-rotate` auf `list`, um eigene Kennungen zu rotieren. Ein einzelner String sendet einen festen User-Agent.
### Cookies
| Cookie | Bedeutung | Beispiel |
| --- | --- | --- |
| `@@title@@` | Titel des Feeds oder des aktuellen Artikels (abhängig vom Kontext). | `Neue Version veröffentlicht` |
| `@@entry!link@@` | Link des aktuellen Artikels. | `https://example.tld/post` |
| `@@entry!link!=href@@` | Wert des `href`-Attributs eines Link-Tags. | `https://example.tld/post` |
| `@@entry!author!name@@` | Name des Autors im Artikel. | `Jane Doe` |
| `@@published@@` | Automatisch ermittelter Veröffentlichungszeitpunkt (nutzt `pubDate`, `published`, `updated` oder `dc:date` und fügt nur bei Erfolg ` – Datum` an). | ` – Tue, 01 Oct 2024 12:00:00 +0200` |
## Beispieldateien und Konvertierung
Das Repository enthält bearbeitbare Beispiele in [`rss-set.tcl`](../rss-set.tcl) und [`rss-set.toml`](../rss-set.toml). Feed-URLs, Channel-Namen und Datenbankpfade sind Platzhalter und müssen angepasst werden.
Vertrauenswürdige Konfigurationsdateien lassen sich mit `tools/config-convert.tcl` umwandeln. Beide Richtungen benötigen `tomltcl`. Tcl-Konfigurationsdateien werden während der Konvertierung ausgeführt; konvertiere daher nur vertrauenswürdige Dateien.
### Logging & DCC beruhigen
Eggdrop schreibt Skriptmeldungen in die Party-Line (DCC-Chat). Wer den Chat ruhig halten möchte, kann das Logging puffern:
1. In der Standardkonfiguration `log-mode` auf `buffered` setzen.
2. Mit `log-interval` festlegen, wie viele Minuten zwischen zwei Sammelmeldungen liegen sollen (die Zusammenfassung enthält Anzahl pro Level sowie erste/letzte Meldung).
Im Pufferbetrieb werden einzelne Meldungen nicht mehr sofort angezeigt, sondern als kompakte Übersicht nach Ablauf des Intervalls ausgegeben. Mit `immediate` lässt sich das alte Verhalten jederzeit wiederherstellen.
## Kompatibilität & Versionen
- Benötigt einen Eggdrop mit Tcl-Unterstützung und dem Standardpaket `http`; optionale Features setzen `base64`, `tls` und `Trf` voraus (`package require …` in `rss-synd.tcl`).
- HTTPS-Zertifikate werden standardmäßig geprüft. Das Skript aktiviert TLS 1.2/1.3 und registriert eigene TLS-Sockets.
- `https-allow-legacy` erlaubt ältere TLS-Protokolle als Fallback und ist unsicher; aktiviere es nur, wenn der Server es erfordert.