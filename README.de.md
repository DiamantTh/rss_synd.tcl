# RSS Synd Script

> **Englische Version:** Siehe [README.md](README.md).

[![Lizenz: BSD-3-Clause](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](LICENSE)

Der übernommene Code steht unter BSD-3-Clause. Das ursprüngliche Skript stammt von Andrew Scott; HM2K ist als früherer Mitwirkender genannt. Pho3niX (MICE07) passte den Code an; DiamantTh pflegt diesen Fork.

RSS Synd ist ein Eggdrop-Tcl-Skript, das RSS- und Atom-Feeds abruft und neue Einträge in IRC-Kanälen ankündigt.

## Funktionen

- Ruft mehrere Feeds regelmäßig ab und kündigt neue Einträge an.
- Unterstützt HTTPS, HTTP-Authentifizierung und optionale Gzip-Dekomprimierung.
- Bietet Trigger, Ausgabeformate und Ankündigungseinstellungen pro Feed.
- Unterstützt Tcl- oder TOML-Konfiguration.

## Schnellstart

1. Kopiere `rss-synd.tcl` und `rss-set.tcl` in das Skriptverzeichnis deines Eggdrop. Für TOML kopiere zusätzlich `rss-set.toml`.
2. Passe Feed-URL, Channel und Datenbankpfad in der Beispieldatei an.
3. Binde `rss-synd.tcl` in `eggdrop.conf` ein, zum Beispiel mit `source scripts/rss-synd.tcl`.

Die mitgelieferte Datei `rss-set.tcl` wählt Tcl als Konfigurationsformat. Für TOML stelle `settings(config-format)` auf `toml` und installiere `tomltcl`.

## Optionale Pakete

| Funktion | Tcl-Paket |
|---------|-----------|
| HTTPS | `tls` |
| HTTP-Authentifizierung | `base64` aus Tcllib |
| Gzip-Dekomprimierung | Tcl 8.6 `zlib` (eingebaut) |
| TOML-Konfiguration und Konvertierung | [`tomltcl`](https://github.com/avohra25/tomltcl) |

Die [Konfigurationsanleitung](docs/configuration.de.md) enthält Optionen, Ausgabe-Cookies, Logging und Konvertierung. Die [Tcl-Beispieldatei](rss-set.tcl) und [TOML-Beispieldatei](rss-set.toml) enthalten Platzhalter für Feed-Angaben.

## Lizenz und Herkunft

Der übernommene Code wird unter der [BSD-3-Clause-Lizenz](LICENSE) veröffentlicht. Andrew Scott schrieb das ursprüngliche Skript; HM2K ist als früherer Mitwirkender genannt. Pho3niX (MICE07) passte den Code 2014 an; DiamantTh pflegt diesen Fork. Siehe das [Upstream-Projekt](https://github.com/eggtcl/rss-synd) und das [MICE07-Vorgänger-Repository](https://github.com/MICE07/rss_synd.tcl).

