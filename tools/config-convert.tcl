# config-convert.tcl -- Hilfsskript zur Konvertierung der rss_synd.tcl-Konfiguration
#
# Aufruf:
#   tclsh tools/config-convert.tcl --from <toml|tcl> --to <toml|tcl> --input <Datei> --output <Datei|->
#
# Optionen:
#   --from   Quellformat der Konfiguration ("toml" oder "tcl").
#   --to     Zielformat der Konfiguration ("toml" oder "tcl").
#   --input  Pfad zur Eingabedatei.
#   --output Pfad zur Ausgabedatei. "-" schreibt nach stdout.

namespace eval ::config_convert {
        variable scriptDir [file dirname [file normalize [info script]]]
        variable projectRoot [file normalize [file join $scriptDir ..]]

        proc parse_args {argv} {
                set options [dict create from {} to {} input {} output {} help 0]

                while {[llength $argv] > 0} {
                        set arg [lindex $argv 0]
                        set argv [lrange $argv 1 end]
                        switch -exact -- $arg {
                                --from -
                                --to -
                                --input -
                                --output {
                                        if {[llength $argv] == 0} {
                                                error "Fehlender Wert für Option '$arg'"
                                        }
                                        dict set options [string range $arg 2 end] [lindex $argv 0]
                                        set argv [lrange $argv 1 end]
                                }
                                --help {
                                        dict set options help 1
                                }
                                default {
                                        error "Unbekannte Option '$arg'"
                                }
                        }
                }

                return $options
        }

        proc normalize_format {value} {
                set normalized [string tolower $value]
                if {$normalized ni {toml tcl}} {
                        error "Unbekanntes Format '$value'"
                }
                return $normalized
        }

        proc ensure_toml_package {} {
                if {[catch {package require toml} err]} {
                        error "Das Paket 'toml' ist erforderlich: $err"
                }
        }

        proc write_file {path data} {
                if {$path eq "-"} {
                        puts stdout $data
                        return
                }

                set dir [file dirname $path]
                if {![file exists $dir]} {
                        if {[catch {file mkdir $dir} err]} {
                                error "Kann Ausgabeverzeichnis '$dir' nicht erstellen: $err"
                        }
                }

                if {[catch {set fh [open $path w]} err]} {
                        error "Kann Ausgabedatei '$path' nicht öffnen: $err"
                }
                try {
                        puts $fh $data
                } finally {
                        close $fh
                }
        }

        proc format_tcl_output {configDict} {
                set defaults {}
                set defaultsDict [dict get $configDict defaults]
                foreach key [lsort [dict keys $defaultsDict]] {
                        lappend defaults $key [dict get $defaultsDict $key]
                }
                set lines [list [format "set default {%s}" [list {*}$defaults]] ""]

                set feedsDict [dict get $configDict feeds]
                foreach feedName [lsort [dict keys $feedsDict]] {
                        set feedList {}
                        set feedDict [dict get $feedsDict $feedName]
                        foreach key [lsort [dict keys $feedDict]] {
                                lappend feedList $key [dict get $feedDict $key]
                        }
                        lappend lines [format "set rss(%s) {%s}" $feedName [list {*}$feedList]]
                }
                return [join $lines "\n"]
        }

        proc format_toml_output {configDict} {
                ensure_toml_package
                return [::toml::encode $configDict]
        }

        proc ensure_runtime_stubs {} {
                if {![llength [info commands ::putlog]]} {
                        proc ::putlog {args} {}
                }
                if {![llength [info commands ::putserv]]} {
                        proc ::putserv {args} {}
                }
                if {![llength [info commands ::botonchan]]} {
                        proc ::botonchan {chan} {return 1}
                }
                if {![llength [info commands ::bind]]} {
                        proc ::bind {args} {}
                }
                if {![llength [info commands ::unbind]]} {
                        proc ::unbind {args} {}
                }
                if {![llength [info commands ::utimer]]} {
                        proc ::utimer {args} {return {}}
                }
                if {![llength [info commands ::killutimer]]} {
                        proc ::killutimer {args} {return {}}
                }
                if {![llength [info commands ::is_utf8_patched]]} {
                        proc ::is_utf8_patched {} {return 0}
                }
        }

        proc load_configuration {format inputPath} {
                variable projectRoot

                set scriptPath [file join $projectRoot rss_synd.tcl]
                if {![file exists $scriptPath]} {
                        error "rss_synd.tcl nicht gefunden unter '$scriptPath'"
                }

                ensure_runtime_stubs

                if {[catch {source $scriptPath} err]} {
                        error "Fehler beim Laden von '$scriptPath': $err"
                }

                namespace eval ::rss-synd { variable settings }
                upvar 0 ::rss-synd::settings settings
                set formatLower [string tolower $format]
                switch -exact -- $formatLower {
                        toml {
                                set settings(config-format) toml
                                set settings(config-toml-file) $inputPath
                                set settings(config-tcl-file) {}
                        }
                        tcl {
                                set settings(config-format) tcl
                                set settings(config-tcl-file) $inputPath
                                set settings(config-toml-file) {}
                        }
                }

                if {[catch {::rss-synd::load_config} err]} {
                        error "Konfiguration konnte nicht geladen werden: $err"
                }

                return [::rss-synd::configuration_to_dict]
        }

        proc main {argv} {
                set parsed [parse_args $argv]
                if {[dict get $parsed help]} {
                        puts "Verwendung: tclsh tools/config-convert.tcl --from <toml|tcl> --to <toml|tcl> --input <Datei> --output <Datei|->"
                        return 0
                }

                set from [dict get $parsed from]
                set to [dict get $parsed to]
                set input [dict get $parsed input]
                set output [dict get $parsed output]

                if {$from eq "" || $to eq "" || $input eq "" || $output eq ""} {
                        error "Die Optionen --from, --to, --input und --output sind Pflicht."
                }

                set from [normalize_format $from]
                set to [normalize_format $to]

                if {$from eq $to} {
                        error "Quell- und Zielformat dürfen nicht identisch sein."
                }

                set input [file normalize $input]
                if {![file exists $input]} {
                        error "Eingabedatei '$input' wurde nicht gefunden."
                }

                if {$to eq "toml"} {
                        ensure_toml_package
                }

                set configDict [load_configuration $from $input]

                switch -exact -- $to {
                        toml {
                                set content [format_toml_output $configDict]
                        }
                        tcl {
                                set content [format_tcl_output $configDict]
                        }
                }

                write_file $output $content
                return 0
        }
}

if {[info exists argv0] && [file tail [info script]] eq [file tail $argv0]} {
        if {[catch {::config_convert::main $argv} err opts]} {
                puts stderr "config-convert: $err"
                if {[dict exists $opts -errorinfo]} {
                        puts stderr [dict get $opts -errorinfo]
                }
                exit 1
        }
        exit 0
}
