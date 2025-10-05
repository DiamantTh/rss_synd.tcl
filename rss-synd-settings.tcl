#
# Konfigurationsschalter für rss_synd.tcl
#
# Variante "toml":
#   - Standardmodus, liest Einstellungen aus "rss-synd.toml".
#   - Erfordert das Tcllib-Paket "toml".
# Variante "tcl":
#   - Lädt klassische Tcl-Listen aus der in "config-tcl-file" angegebenen Datei.
#   - Ohne Angabe wird der eingebaute Fallback aus rss_synd.tcl genutzt.
#

namespace eval ::rss-synd {
    variable settings

    if {![info exists settings(config-format)] || $settings(config-format) eq ""} {
        set settings(config-format) toml
    }

    if {![info exists settings(config-toml-file)]} {
        set settings(config-toml-file) ""
    }

    if {![info exists settings(config-tcl-file)]} {
        set settings(config-tcl-file) ""
    }

    if {![info exists settings(debug-mode)]} {
        set settings(debug-mode) {}
    }
}
