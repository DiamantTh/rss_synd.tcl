# config-convert.tcl -- Hilfsskript zur Konvertierung der rss-synd.tcl-Konfiguration
#
# Aufruf:
#   tclsh tools/config-convert.tcl --from <toml|tcl> --to <toml|tcl> --input <Datei> --output <Datei|->
#
# Tcl-Eingaben werden ausgeführt. Nur vertrauenswürdige Dateien verwenden.
#
# Optionen:
#   --from   Quellformat der Konfiguration ("toml" oder "tcl").
#   --to     Zielformat der Konfiguration ("toml" oder "tcl").
#   --input  Pfad zur Eingabedatei.
#   --output Pfad zur Ausgabedatei. "-" schreibt nach stdout.

namespace eval ::config_convert {
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
                if {[catch {package require tomltcl} err]} {
                        error "Das Paket 'tomltcl' ist erforderlich: $err"
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
                        fconfigure $fh -encoding utf-8 -translation lf
                        puts $fh $data
                } finally {
                        close $fh
                }
        }

        proc format_tcl_output {configDict} {
                set body "variable settings\nvariable default\nvariable rss\n"
                append body [list set settings(config-format) tcl] "\n"
                append body [list set default [dict get $configDict defaults]] "\n"
                dict for {name feed} [dict get $configDict feeds] {
                        append body [list set rss($name) $feed] "\n"
                }
                return [list namespace eval ::rss-synd $body]
        }

        proc toml_table {options} {
                set table {}
                dict for {key value} $options {
                        if {$key eq "user-agent" && ![catch {llength $value}]} {
                                set agents {}
                                foreach agent $value {
                                        lappend agents [list string $agent]
                                }
                                set node [list array $agents]
                        } elseif {$key in {announce-output trigger-output remove-empty
                                announce-type max-depth evaluate-tcl update-interval
                                output-order timeout https-allow-legacy enable-gzip log-interval}
                                && [regexp {^-?(0|[1-9][0-9]*)$} $value]
                                && [string is wideinteger -strict $value]} {
                                set node [list integer $value]
                        } else {
                                set node [list string $value]
                        }
                        dict set table $key $node
                }
                return [list table $table]
        }

        proc format_toml_output {configDict} {
                set feeds {}
                dict for {name feed} [dict get $configDict feeds] {
                        dict set feeds $name [toml_table $feed]
                }
                set document [dict create defaults [toml_table [dict get $configDict defaults]] \
                        feeds [list table $feeds]]
                return [::tomltcl::encode [list table $document]]
        }

        proc load_configuration {format inputPath} {
                if {$format eq "toml"} {
                        set config [::tomltcl::unwrap [::tomltcl::read_file $inputPath]]
                } else {
                        # Tcl settings are executable. Load trusted input in a separate interpreter
                        # so the converter neither starts Eggdrop nor inherits another config.
                        set child [interp create]
                        try {
                                interp eval $child [list namespace eval ::rss-synd \
                                        [list source -encoding utf-8 $inputPath]]
                                set config [interp eval $child {
                                        namespace eval ::rss-synd {
                                                if {![info exists default] && ![array exists rss]} {
                                                        error "Keine Feed-Einstellungen in der Eingabedatei."
                                                }
                                                if {![info exists default]} {set default {}}
                                                dict create defaults $default feeds [array get rss]
                                        }
                                }]
                        } finally {
                                interp delete $child
                        }
                }
                if {![dict exists $config defaults] && ![dict exists $config feeds]} {
                        error "Die Eingabedatei enthält weder defaults noch feeds."
                }
                set result [dict merge {defaults {} feeds {}} $config]
                set defaults [dict get $result defaults]
                dict size $defaults
                dict for {name options} [dict get $result feeds] {
                        dict size $options
                }
                return $result
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

                if {$output ne "-" && [file normalize $output] eq $input} {
                        error "Eingabe- und Ausgabedatei müssen verschieden sein."
                }
                ensure_toml_package

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
