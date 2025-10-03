# RSS Synd Script

## Einleitung
Das Skript `rss_synd.tcl` erweitert Eggdrop-Bots um die Möglichkeit, RSS- und Atom-Feeds automatisiert auszulesen, neue Einträge zu erkennen und sie in IRC-Kanälen anzukündigen. Es unterstützt dabei sichere Verbindungen, benutzerdefinierte Ausgaben und flexible Trigger-Mechanismen.

### Hauptfeatures
- Regelmäßiges Abrufen und Ankündigen mehrerer RSS-/Atom-Feeds.
- Unterstützung für HTTP-Authentifizierung, HTTPS und gzip-komprimierte Feeds.
- Anpassbare Trigger, Ausgabeformate und Ankündigungsoptionen pro Feed.
- Optionales Nachbearbeiten der Ausgaben über Tcl-Ausdrücke.

## Installation
1. Kopiere `rss_synd.tcl` und `rss-synd-settings.tcl` in das Skriptverzeichnis deines Eggdrop-Bots.
2. Ergänze deine `eggdrop.conf` um die Zeile `source scripts/rss-synd.tcl` (Pfad ggf. anpassen).

### Paketinstallation (optionale Features)
| Feature | Benötigtes Paket | Debian/Ubuntu |
|---------|------------------|----------------|
| HTTP-Authentifizierung | `tcllib` (Base64) | `sudo apt-get install tcllib` |
| HTTPS-Unterstützung | `tcl-tls` | `sudo apt-get install tcl-tls` |
| Gzip-Dekomprimierung | `tcl-trf` | `sudo apt-get install tcl-trf` |

## Abhängigkeiten und Hinweise
Das Skript läuft ohne zusätzliche Pakete, jedoch sind bestimmte Funktionen nur mit den oben aufgeführten Erweiterungen verfügbar.

- **HTTPS-Hinweis:** Zertifikate werden standardmäßig geprüft und es sind nur TLS 1.2/1.3 aktiv. Wenn deine Umgebung ausschließlich ältere Protokolle bietet, setze die Option `https-allow-legacy` auf `1` (unsicher, nur für Notfälle).

## Konfiguration
Die folgenden Optionen kannst du global in der Default-Konfiguration oder pro Feed festlegen. Spezifische Feed-Werte überschreiben globale Einstellungen.

### Pflichtfelder
- **`url`** – Adresse des RSS-/Atom-Feeds. Beispiele: `http://www.example.tld/feed.xml`, `https://www.example.tld/feed.xml`, `http://username:password@www.example.tld/feed.xml`.
- **`channels`** – Liste der Kanäle, in denen Feed-Ankündigungen und Trigger aktiv sind (mit Leerzeichen trennen).
- **`database`** – (Relativer) Pfad zur Datenbankdatei, z. B. `./scripts/feedname.db`.
- **`output`** – Ausgabemuster für Ankündigungen im Kanal.
- **`max-depth`** – Maximale Anzahl an Weiterleitungen (HTTP Location-Header). Standard: `5`.
- **`timeout`** – Timeout für Verbindungen in Millisekunden. Standard: `60000`.
- **`user-agent`** – User-Agent-Header für HTTP-Anfragen.
- **`announce-type`** – Modus für automatische Ankündigungen (`0` = Channel-Message, `1` = Channel-Notice). Standard: `0`.
- **`announce-output`** – Maximale Anzahl Artikel pro automatischer Ankündigung (`0` deaktiviert). Standard: `3`.
- **`trigger-type`** – Ausgabeformat bei manuellen Triggern nach dem Schema `<channel>:<privmsg>` (0 = Channel-Message, 1 = Channel-Notice, 2 = User-Message, 3 = User-Notice). Standard: `0:2`.
- **`trigger-output`** – Maximale Anzahl Artikel pro Trigger (`0` deaktiviert). Standard: `3`.
- **`update-interval`** – Abfrageintervall in Minuten (empfohlen ≥ 15). Websites können bei zu häufigen Abfragen sperren. Standard: `30`.

### Optionale Einstellungen
- **`https-allow-legacy`** – Aktiviert bei Bedarf TLS 1.0/1.1, wenn moderne Protokolle nicht verfügbar sind. Bei Rückfall wird eine Warnung geloggt. Standard: `0` (modernes TLS erzwingen).
- **`trigger`** – Öffentlicher Trigger zum Auflisten von Feeds. Wenn nur einmal definiert, nutze `@@feedid@@` als Platzhalter für die Feed-ID.
- **`evaluate-tcl`** – Führt die Ausgabe vor dem Senden als Tcl aus. Standard: `0` (aus).
- **`enable-gzip`** – Aktiviert Gzip-Dekompression für den Feed. Standard: `0` (aus).
- **`remove-empty`** – Entfernt leere Cookies aus der Ausgabe. Standard: `1` (an).
- **`output-order`** – Reihenfolge der Ankündigungen (`0` = Älteste→Neueste, `1` = Neueste→Älteste).
- **`charset`** – Zielzeichensatz der Ausgabe, z. B. `utf-8`, `cp1251`, `iso8859-1`. Standard ist das System-Charset.
- **`feedencoding`** – Zeichensatz des Feeds (oft im `<?xml>`-Header). Beachte die Tcl-Bezeichnungen für Encodings, z. B. `cp1251` statt `windows-1251`.

### Cookies
Die Ausgabe basiert auf einem dynamischen Cookie-System, dessen verfügbare Variablen vom Feed abhängen.

- Seit Version 0.3 kannst du auf beliebige Tags innerhalb eines Artikels oder des gesamten Feeds zugreifen. Verwende das Muster `@@<tag>!<subtag>!...@@`; die Cookies `@@item@@` und `@@entry@@` zeigen stets auf den aktuellen Artikel.
- Attribute eines Tags lassen sich über `=<attribut>` ausgeben, z. B. `@@entry!link!=href@@` für das `href`-Attribut des `<link>`-Tags.
- Weitere Beispiele findest du direkt in `rss_synd.tcl`.
