# RSS Synd Script

> **English version:** Siehe [README.md](README.md).

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
Die folgenden optionalen Funktionen erfordern zusätzliche Tcl-Erweiterungen:

| Feature | Benötigte Tcl-Erweiterungen |
|---------|-----------------------------|
| HTTP-Authentifizierung | `base64` aus `tcllib` |
| HTTPS-Unterstützung | `tls` |
| Gzip-Dekomprimierung | `Trf` |

Installiere die benötigten Erweiterungen je nach Plattform über den jeweiligen Paketmanager, vorgefertigte Tcl-Pakete oder verfügbare Community-Repositorien.

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
| `user-agent` | HTTP-User-Agent-Header; akzeptiert einen statischen String oder eine Tcl-Liste von Kandidaten. Mit `user-agent-rotate` lässt sich eine Rotation (z. B. Listen-Round-Robin oder eine eigene Funktion) aktivieren. | Rotierende Liste aktueller Desktop- und Mobil-Browser-Kennungen (siehe unten) | `Statisch: Mozilla/5.0 (compatible; rss-synd/2025.10; +https://example.tld)`<br>`Rotierend: {"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36" "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"} + user-agent-rotate list` |
| `announce-type` | Modus für automatische Ankündigungen (`0` = Channel-Message, `1` = Channel-Notice). | `0` | `1` |
| `announce-output` | Anzahl Artikel pro Ankündigung (`0` deaktiviert). | `3` | `5` |
| `trigger-type` | Ausgabeformat für Trigger `<channel>:<privmsg>` (`0/1` für Channel, `2/3` für User). | `0:2` | `1:3` |
| `trigger-output` | Anzahl Artikel pro Trigger (`0` deaktiviert). | `3` | `1` |
| `update-interval` | Abrufintervall in Minuten. | `30` | `60` |

### Optionale Einstellungen
| Option | Beschreibung | Standard | Beispiel |
| --- | --- | --- | --- |
| `https-allow-legacy` | Erlaubt TLS 1.0/1.1 als Fallback (unsicher). | `0` | `1` |
| `log-mode` | Logging-Strategie für die Eggdrop-Konsole. `immediate` schreibt Meldungen sofort, `buffered` sammelt sie und fasst sie zusammen. | `immediate` | `buffered` |
| `log-interval` | Minuten bis zur Ausgabe einer zusammengefassten Log-Nachricht, wenn `log-mode` auf `buffered` steht. | `5` | `10` |
| `user-agent-rotate` | Rotationsstrategie für den User-Agent: `list` aktiviert das eingebaute Round-Robin, alternativ kann der Name einer Prozedur angegeben werden, die den nächsten Eintrag liefert. Der Aufruf erhält Feed-Namen und aktuelle Einstellungen und darf einen String oder ein Dict mit `user-agent` plus Zusatzwerten zurückgeben. | `list` | `list` / `::mein::ua::next` |
| `trigger` | Öffentlicher Triggertext; `@@feedid@@` wird durch die Feed-ID ersetzt. | `!rss @@feedid@@` | `!news @@feedid@@` |
| `evaluate-tcl` | Führt Ausgaben vor dem Senden als Tcl aus. | `0` | `1` |
| `enable-gzip` | Aktiviert Gzip-Dekomprimierung für Feeds. | `0` | `1` |
| `remove-empty` | Entfernt leere Cookies aus der Ausgabe. | `1` | `0` |
| `output-order` | Reihenfolge der Artikel (`0` = älteste→neueste, `1` = neueste→älteste). | `0` | `1` |
| `charset` | Zielzeichensatz für Nachrichten. | Systemstandard | `utf-8` |
| `feedencoding` | Erzwingt einen Zeichensatz beim Einlesen des Feeds. | – | `cp1251` |

### Vorkonfigurierte User-Agent-Rotation

Die Standardkonfiguration bringt eine kuratierte Auswahl aktueller (Mitte 2025) Browser-Kennungen für wichtige Desktop- und Mobil-Plattformen mit:

```tcl
{
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36"
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
    "Mozilla/5.0 (iPad; CPU OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
    "Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro Build/AP2A.240605.024) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.6533.72 Mobile Safari/537.36"
    "Mozilla/5.0 (Linux; Android 14; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Mobile Safari/537.36"
}
```

Du kannst die Liste jederzeit anpassen, eigene Marken ergänzen oder wieder auf einen einzelnen Header umstellen, indem du einen String hinterlegst und `user-agent-rotate` leerst.

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
        "log-mode"              "immediate"
        "log-interval"         5
        "timeout"               60000
        "channels"              "#channel"
        "trigger"               "!rss @@feedid@@"
        "output"                "[\002@@channel!title@@@@title@@\002] @@item!title@@@@entry!title@@ - @@item!link@@@@entry!link!=href@@"
        "user-agent"            {
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36"
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36"
            "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
            "Mozilla/5.0 (iPad; CPU OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
            "Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro Build/AP2A.240605.024) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.6533.72 Mobile Safari/537.36"
            "Mozilla/5.0 (Linux; Android 14; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Mobile Safari/537.36"
        }
        "user-agent-rotate"    "list"
        "https-allow-legacy"    0
    }
}
```

### Logging & DCC beruhigen

Eggdrop schreibt Skriptmeldungen in die Party-Line (DCC-Chat). Wer den Chat ruhig halten möchte, kann das Logging puffern:

1. In der Standardkonfiguration `log-mode` auf `buffered` setzen.
2. Mit `log-interval` festlegen, wie viele Minuten zwischen zwei Sammelmeldungen liegen sollen (die Zusammenfassung enthält Anzahl pro Level sowie erste/letzte Meldung).

Im Pufferbetrieb werden einzelne Meldungen nicht mehr sofort angezeigt, sondern als kompakte Übersicht nach Ablauf des Intervalls ausgegeben. Mit `immediate` lässt sich das alte Verhalten jederzeit wiederherstellen.

## Kompatibilität & Versionen
- Skriptversion git-198a7a4 vom 03.10.2025. Die Versionsinformationen findest du direkt im Kopfbereich von `rss_synd.tcl`.
- Benötigt einen Eggdrop mit Tcl-Unterstützung und dem Standardpaket `http`; optionale Features setzen `base64`, `tls` und `Trf` voraus (`package require …` in `rss_synd.tcl`).
- Für HTTPS-Verbindungen initialisiert das Skript standardmäßig TLS 1.2/1.3 und registriert eigene TLS-Sockets; über `https-allow-legacy` kannst du bei Bedarf ältere Protokolle freischalten.
