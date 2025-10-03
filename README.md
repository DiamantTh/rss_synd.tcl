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
| Option | Beschreibung | Standard | Beispiel |
| --- | --- | --- | --- |
| `url` | Adresse des RSS-/Atom-Feeds. | – | `https://example.tld/feed.xml` |
| `channels` | Liste der Kanäle für Ankündigungen und Trigger (Leerzeichen-getrennt). | `#channel` | `#news #alerts` |
| `database` | Pfad zur Datenbankdatei. | – | `./scripts/news.db` |
| `output` | Nachrichtenformat mit Cookies für Ankündigungen. | `[\002@@channel!title@@@@title@@\002] @@item!title@@@@entry!title@@ - @@item!link@@@@entry!link!=href@@` | `[\002@@channel!title@@\002] @@item!title@@ – @@item!link@@` |
| `max-depth` | Maximale Anzahl erlaubter HTTP-Weiterleitungen. | `5` | `3` |
| `timeout` | Verbindungs-Timeout in Millisekunden. | `60000` | `45000` |
| `user-agent` | HTTP User-Agent-Header. | `Mozilla/5.0 (Windows; U; Windows NT 6.1; en-GB; rv:1.9.2.2) Gecko/20100316 Firefox/3.6.2` | `rss-synd/0.5.1 (+https://example.tld)` |
| `announce-type` | Modus für automatische Ankündigungen (`0` = Channel-Message, `1` = Channel-Notice). | `0` | `1` |
| `announce-output` | Anzahl Artikel pro Ankündigung (`0` deaktiviert). | `3` | `5` |
| `trigger-type` | Ausgabeformat für Trigger `<channel>:<privmsg>` (`0/1` für Channel, `2/3` für User). | `0:2` | `1:3` |
| `trigger-output` | Anzahl Artikel pro Trigger (`0` deaktiviert). | `3` | `1` |
| `update-interval` | Abrufintervall in Minuten. | `30` | `60` |

### Optionale Einstellungen
| Option | Beschreibung | Standard | Beispiel |
| --- | --- | --- | --- |
| `https-allow-legacy` | Erlaubt TLS 1.0/1.1 als Fallback (unsicher). | `0` | `1` |
| `trigger` | Öffentlicher Triggertext; `@@feedid@@` wird durch die Feed-ID ersetzt. | `!rss @@feedid@@` | `!news @@feedid@@` |
| `evaluate-tcl` | Führt Ausgaben vor dem Senden als Tcl aus. | `0` | `1` |
| `enable-gzip` | Aktiviert Gzip-Dekomprimierung für Feeds. | `0` | `1` |
| `remove-empty` | Entfernt leere Cookies aus der Ausgabe. | `1` | `0` |
| `output-order` | Reihenfolge der Artikel (`0` = älteste→neueste, `1` = neueste→älteste). | `0` | `1` |
| `charset` | Zielzeichensatz für Nachrichten. | Systemstandard | `utf-8` |
| `feedencoding` | Erzwingt einen Zeichensatz beim Einlesen des Feeds. | – | `cp1251` |

### Cookies
| Cookie | Bedeutung | Beispiel |
| --- | --- | --- |
| `@@title@@` | Titel des Feeds oder des aktuellen Artikels (abhängig vom Kontext). | `Neue Version veröffentlicht` |
| `@@entry!link@@` | Link des aktuellen Artikels. | `https://example.tld/post` |
| `@@entry!link!=href@@` | Wert des `href`-Attributs eines Link-Tags. | `https://example.tld/post` |
| `@@entry!author!name@@` | Name des Autors im Artikel. | `Jane Doe` |

## Beispielkonfiguration
```tcl
namespace eval ::rss-synd {
    set rss(news) {
        "url"       "https://example.tld/feed.xml"
        "channels"  "#news #alerts"
        "database"  "./scripts/news.db"
        "output"    "[\002@@channel!title@@@@title@@\002] @@item!title@@ - @@item!link@@"
        "trigger"   "!news @@feedid@@"
    }

    set default {
        "announce-output"       3
        "trigger-output"        3
        "remove-empty"          1
        "trigger-type"          0:2
        "announce-type"         0
        "max-depth"             5
        "evaluate-tcl"          0
        "update-interval"       30
        "output-order"          0
        "timeout"               60000
        "channels"              "#channel"
        "trigger"               "!rss @@feedid@@"
        "output"                "[\002@@channel!title@@@@title@@\002] @@item!title@@@@entry!title@@ - @@item!link@@@@entry!link!=href@@"
        "user-agent"            "Mozilla/5.0 (Windows; U; Windows NT 6.1; en-GB; rv:1.9.2.2) Gecko/20100316 Firefox/3.6.2"
        "https-allow-legacy"    0
    }
}
```

## Kompatibilität & Versionen
- Skriptversion 0.5.1 vom 07.11.2014. Die Versionsinformationen findest du direkt im Kopfbereich von `rss_synd.tcl`.
- Benötigt einen Eggdrop mit Tcl-Unterstützung und dem Standardpaket `http`; optionale Features setzen `base64`, `tls` und `Trf` voraus (`package require …` in `rss_synd.tcl`).
- Für HTTPS-Verbindungen initialisiert das Skript standardmäßig TLS 1.2/1.3 und registriert eigene TLS-Sockets; über `https-allow-legacy` kannst du bei Bedarf ältere Protokolle freischalten.
