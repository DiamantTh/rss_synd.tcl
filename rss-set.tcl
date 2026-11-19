# Beispielkonfiguration. URL, Channel und Datenbankpfad bitte anpassen.
# Für TOML: config-format auf toml setzen und rss-set.toml bearbeiten.
namespace eval ::rss-synd {
    variable settings
    variable default
    variable rss
    set settings(config-format) tcl
    set settings(config-tcl-file) {}
    set settings(config-toml-file) {}
    set default {
        announce-output 3
        trigger-output 3
        remove-empty 1
        trigger-type 0:2
        announce-type 0
        max-depth 5
        evaluate-tcl 0
        update-interval 30
        output-order 0
        log-mode immediate
        log-interval 5
        timeout 60000
        channels "#example"
        trigger "!rss @@feedid@@"
        output "@@item!title@@@@entry!title@@ - @@item!link@@@@entry!link!=href@@"
        user-agent {"rss-synd/1.0"}
        https-allow-legacy 0
    }
    set rss(example) {
        url "https://example.com/feed.xml"
        channels "#example"
        database "./scripts/feeds/example.db"
        trigger "!example"
    }
}
