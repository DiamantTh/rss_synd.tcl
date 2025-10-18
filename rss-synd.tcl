#   Highly configurable asynchronous RSS & Atom feed reader for Eggdrops 
#     written in TCL. Supports multiple feeds, gzip compressed feeds,
#     automatically messaging channels with updates at set intervals,
#     custom private/channel triggers and more.
#
#
# Name: RSS & Atom Syndication Script for Eggdrop
# Author: Pho3niX (Original)
# Maintainer: DiamantTh <https://github.com/DiamantTh>
# Link: https://github.com/MICE07/rss_synd.tcl
# Tags: rss, atom, syndication
# Updated: 18-Oct-2025
#
# -*- tab-width: 4; indent-tabs-mode: t; -*-

#
# Logging-Hilfsfunktionen und Einstellungen
#

namespace eval ::rss-synd {
        variable logQueue {}
        variable logTimer ""
        variable logMode immediate
        variable logInterval 5

        variable debugOptions
        set debugOptions [dict create \
                enabled 0 \
                tls 0 \
                http 0 \
                redirect 0 \
                modes {} \
                raw "" \
                tls-callback 0]

        variable scriptBaseDir [file dirname [info script]]

        variable settings
        array set settings {config-format toml config-tcl-file {} config-toml-file {}}

        variable debugOptions
        set debugOptions [dict create http 0 tls 0]

        variable fallbackDefault [list \
                "announce-output"       0 \
                "trigger-output"        0 \
                "trigger-fetch"         0 \
                "remove-empty"          1 \
                "trigger-type"          0:2 \
                "announce-type"         0 \
                "max-depth"             5 \
                "evaluate-tcl"          0 \
                "update-interval"       30 \
                "output-order"          0 \
                "log-mode"              immediate \
                "log-interval"          5 \
                "timeout"               60000 \
                "channels"              {} \
                "trigger"               "" \
                "output"                "" \
                "user-agent"            [list \
                        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36" \
                        "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36" \
                        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36" \
                        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1" \
                        "Mozilla/5.0 (iPad; CPU OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1" \
                        "Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro Build/AP2A.240605.024) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.6533.72 Mobile Safari/537.36" \
                        "Mozilla/5.0 (Linux; Android 14; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Mobile Safari/537.36" \
                ] \
                "user-agent-rotate"     list \
                "https-allow-legacy"    0 \
                "tls-ca-file"           {} \
                "tls-ca-dir"            {} \
                "tls-cert-file"         {} \
                "tls-key-file"          {} \
        ]

        variable fallbackFeeds [dict create \
                msbulletins [list \
                        "url"                   "https://technet.microsoft.com/en-us/security/rss/bulletin" \
                        "channels"              {} \
                        "database"              "/path to dir/msbulletins.db" \
                        "output"                "" \
                        "trigger"               "" \
                        "announce-output"       0 \
                        "trigger-output"        0 \
                        "update-interval"       10 \
                        "output-order"          0 \
                ] \
        ]

        variable tlsStatus [dict create \
                summary {} \
                warnings {} \
                available 0 \
                version {} \
                paths {} \
                timestamp 0]
}

proc ::rss-synd::log_preview {text} {
	set normalized [string map {"\n" " " "\r" " "} $text]
	regsub -all {\s+} $normalized { } normalized
	set limit 160
	if {[string length $normalized] > $limit} {
		set normalized "[string range $normalized 0 [expr {$limit - 4}]] ..."
	}
	return [string trim $normalized]
}

proc ::rss-synd::flush_log_queue {} {
	variable logQueue
	variable logTimer

	if {$logTimer ne ""} {
		catch {killutimer $logTimer}
		set logTimer ""
	}
	if {[llength $logQueue] == 0} {
		return
	}
	set total [llength $logQueue]
	set counts [dict create]
	foreach entry $logQueue {
		set level [dict get $entry level]
		dict incr counts [string tolower $level]
	}
	set summaryParts {}
	dict for {lvl count} $counts {
		lappend summaryParts "${lvl}=$count"
	}
	set firstEntry [lindex $logQueue 0]
	set lastEntry [lindex $logQueue end]
	set firstLevel [dict get $firstEntry level]
	set lastLevel [dict get $lastEntry level]
	set firstText [::rss-synd::log_preview [dict get $firstEntry text]]
	set lastText [::rss-synd::log_preview [dict get $lastEntry text]]
	set summary "\002RSS Log\002: $total Meldungen"
	if {[llength $summaryParts] > 0} {
		append summary " (" [join $summaryParts ", "] ")"
	}
	append summary ", Erste " {\[} $firstLevel {\]: } $firstText
	if {$total > 1} {
		append summary " – Letzte " {\[} $lastLevel {\]: } $lastText
	}
	putlog $summary
	set logQueue {}
}

proc ::rss-synd::configure_logging {{settingsList {}}} {
        variable default
        variable logMode
        variable logInterval
        variable logQueue
        variable logTimer

	set mode immediate
	set interval 5
	set configList {}
	if {[llength $settingsList] > 0} {
		set configList $settingsList
	} elseif {[info exists default]} {
		set configList $default
	}
	if {[llength $configList] > 0} {
		array set cfg $configList
		if {[info exists cfg(log-mode)]} {
			set mode [string tolower $cfg(log-mode)]
		}
		if {[info exists cfg(log-interval)]} {
			set interval $cfg(log-interval)
		}
	}
	if {![string is double -strict $interval]} {
		set interval 0
	}
	set interval [expr {double($interval)}]
	if {$mode ni {immediate buffered}} {
		set mode immediate
	}
	if {$mode eq "buffered" && $interval <= 0} {
		set mode immediate
	}
	set logMode $mode
	set logInterval $interval
	if {$logMode eq "immediate"} {
		if {$logTimer ne ""} {
			catch {killutimer $logTimer}
			set logTimer ""
		}
		if {[llength $logQueue] > 0} {
			::rss-synd::flush_log_queue
		}
        }
}

proc ::rss-synd::configure_debug {} {
        variable settings
        variable debugOptions

        set debugOptions [dict create http 0 tls 0]

        if {![info exists settings(debug-mode)] || $settings(debug-mode) eq ""} {
                return
        }

        set entries {}
        if {[catch {set entries [lrange $settings(debug-mode) 0 end]}]} {
                set entries [list $settings(debug-mode)]
        }

        foreach entry $entries {
                set normalized [string tolower $entry]
                switch -exact -- $normalized {
                        http {
                                dict set debugOptions http 1
                        }
                        tls {
                                dict set debugOptions tls 1
                        }
                        all {
                                dict set debugOptions http 1
                                dict set debugOptions tls 1
                        }
                        default {
                                ::rss-synd::log_message warning "\002RSS Warnung\002: Unbekannter debug-mode-Wert '$entry' wird ignoriert."
                        }
                }
        }
}

proc ::rss-synd::format_header_debug {headersList} {
        if {![llength $headersList]} {
                return "keine"
        }

        set headerParts {}
        if {[expr {[llength $headersList] % 2}] == 0} {
                foreach {key value} $headersList {
                        lappend headerParts "$key: $value"
                }
        }

        if {[llength $headerParts] == 0} {
                return [join $headersList ", "]
        }

        return [join $headerParts ", "]
}

proc ::rss-synd::log_message {level text} {
        variable logMode
        variable logInterval
        variable logQueue
        variable logTimer

	set mode [string tolower $logMode]
	set intervalMinutes $logInterval
	if {![string is double -strict $intervalMinutes]} {
		set intervalMinutes 0
	}
	if {$mode ne "buffered"} {
		if {[llength $logQueue] > 0} {
			::rss-synd::flush_log_queue
		}
		putlog $text
		return
	}
	if {$intervalMinutes <= 0} {
		if {[llength $logQueue] > 0} {
			::rss-synd::flush_log_queue
		}
		putlog $text
		return
	}
	set entry [dict create level $level text $text time [clock seconds]]
	lappend logQueue $entry
	if {$logTimer eq ""} {
		set seconds [expr {int(ceil($intervalMinutes * 60.0))}]
		if {$seconds < 1} {
			set seconds 1
		}
		set logTimer [utimer $seconds [list ::rss-synd::flush_log_queue]]
        }
}

proc ::rss-synd::tls_debug_logger {args} {
        set message [string trim [join $args " "]]
        if {$message eq ""} {
                set message "(no details)"
        }
        ::rss-synd::log_message debug "\002RSS TLS Debug\002: $message"
}

proc ::rss-synd::configure_debug {{settingsList {}}} {
        variable debugOptions
        variable settings
        variable packages

        set debugSpec ""
        set provided {}

        if {[llength $settingsList] > 0} {
                set provided $settingsList
        } elseif {[info exists settings] && [array exists settings]} {
                set provided [array get settings]
        }

        if {[llength $provided] > 0} {
                array set cfg $provided
                if {[info exists cfg(debug-mode)]} {
                        set debugSpec $cfg(debug-mode)
                }
        }

        set normalized [string map {"," " " ";" " "} $debugSpec]
        set tokens {}
        foreach token [split $normalized] {
                set trimmed [string tolower [string trim $token]]
                if {$trimmed eq ""} {
                        continue
                }
                lappend tokens $trimmed
        }

        set allowTls 0
        set allowHttp 0
        set allowRedirect 0
        set enabled 0

        if {[llength $tokens] > 0} {
                foreach token $tokens {
                        switch -nocase -- $token {
                                {all} -
                                {full} -
                                {debug} -
                                {on} -
                                {true} -
                                {1} -
                                {yes} {
                                        set allowTls 1
                                        set allowHttp 1
                                        set allowRedirect 1
                                        set enabled 1
                                }
                                {tls} {
                                        set allowTls 1
                                        set enabled 1
                                }
                                {http} {
                                        set allowHttp 1
                                        set enabled 1
                                }
                                {redirect} -
                                {redirects} {
                                        set allowRedirect 1
                                        set enabled 1
                                }
                                {off} -
                                {none} -
                                {disable} -
                                {disabled} -
                                {false} -
                                {0} {
                                        set allowTls 0
                                        set allowHttp 0
                                        set allowRedirect 0
                                        set enabled 0
                                        break
                                }
                                default {
                                        # unbekannte Token werden ignoriert
                                }
                        }
                }
        }

        if {!$enabled && ($allowTls || $allowHttp || $allowRedirect)} {
                set enabled 1
        }

        set activeModes {}
        if {$allowTls} {
                lappend activeModes tls
        }
        if {$allowHttp} {
                lappend activeModes http
        }
        if {$allowRedirect} {
                lappend activeModes redirect
        }

        set tlsSupported 0
        if {[info exists packages] && [array exists packages] && [info exists packages(tls)]} {
                if {$packages(tls) == 0} {
                        set tlsSupported 1
                }
        }

        set tlsCallbackActive 0
        if {$allowTls} {
                if {$tlsSupported && [info commands ::tls::debug] ne ""} {
                        if {[catch {::tls::debug ::rss-synd::tls_debug_logger} err]} {
                                ::rss-synd::log_message warning "\002RSS Warnung\002: TLS-Debug konnte nicht aktiviert werden: $err"
                        } else {
                                set tlsCallbackActive 1
                        }
                } else {
                        if {$enabled} {
                                ::rss-synd::log_message info "\002RSS Hinweis\002: TLS-Debug ist angefordert, aber nicht verfügbar (Paket fehlt oder ::tls::debug unbekannt)."
                        }
                }
        } elseif {[info commands ::tls::debug] ne ""} {
                catch {::tls::debug {}}
        }

        set debugOptions [dict create \
                enabled $enabled \
                tls $allowTls \
                http $allowHttp \
                redirect $allowRedirect \
                modes $activeModes \
                raw $debugSpec \
                "tls-callback" $tlsCallbackActive]

        return $debugOptions
}

#
# Konfigurationsverwaltung
#

proc ::rss-synd::resolve_path {path baseDir} {
        if {$path eq ""} {
                return ""
        }
        set pathtype [file pathtype $path]
        if {$pathtype eq "relative"} {
                return [file normalize [file join $baseDir $path]]
        }
        return [file normalize $path]
}

proc ::rss-synd::use_fallback_config {{message ""}} {
        variable default
        variable rss
        variable fallbackDefault
        variable fallbackFeeds

        set default $fallbackDefault
        catch {array unset rss}
        array set rss {}
        dict for {feedName feedList} $fallbackFeeds {
                set rss($feedName) $feedList
        }
        if {$message ne ""} {
                ::rss-synd::log_message warning $message
        }
}

proc ::rss-synd::load_config {} {
        variable settings
        variable default
        variable rss
        variable fallbackDefault
        variable fallbackFeeds

        variable scriptBaseDir

        if {[info exists scriptBaseDir] && $scriptBaseDir ne ""} {
                set scriptDir $scriptBaseDir
        } else {
                set scriptDir [file dirname [info script]]
        }
        set togglesFile [file normalize [file join $scriptDir rss-set.tcl]]
        set togglesExample [file normalize [file join $scriptDir rss-set.example.tcl]]
        set usingExampleToggles 0

        if {![file exists $togglesFile]} {
                if {[file exists $togglesExample]} {
                        set togglesFile $togglesExample
                        set usingExampleToggles 1
                } else {
                        ::rss-synd::use_fallback_config [format "\002RSS Warnung\002: Einstellungsdatei '%s' fehlt. Bitte 'rss-set.example.tcl' nach 'rss-set.tcl' kopieren und anpassen." $togglesFile]
                        return
                }
        }

        set preserved {}
        if {[array exists settings]} {
                set preserved [array get settings]
        }

        catch {array unset settings}
        array set settings {config-format toml config-tcl-file {} config-toml-file {}}

        if {[llength $preserved] > 0} {
                array set settings $preserved
        }

        if {[catch {source $togglesFile} err]} {
                ::rss-synd::use_fallback_config "\002RSS Warnung\002: Umschaltdatei konnte nicht geladen werden: $err"
                return
        }

        if {$usingExampleToggles} {
                ::rss-synd::log_message warning "\002RSS Hinweis\002: Beispiel-Umschaltdatei '$togglesFile' wird verwendet. Bitte nach 'rss-set.tcl' kopieren und anpassen."
        }

        if {![info exists settings(config-format)] || $settings(config-format) eq ""} {
                set settings(config-format) toml
        }

        set format [string tolower $settings(config-format)]
        if {$format ni {toml tcl}} {
                set format toml
        }

        if {$format eq "tcl"} {
                set configFile $settings(config-tcl-file)
                if {$configFile eq ""} {
                        set configFile $togglesFile
                }
                set configFile [::rss-synd::resolve_path $configFile $scriptDir]
                if {[catch {source $configFile} err]} {
                        ::rss-synd::use_fallback_config "\002RSS Fehler\002: Tcl-Konfigurationsdatei konnte nicht geladen werden: $err"
                        return
                }
                if {![info exists default] || [llength $default] == 0} {
                        set default $fallbackDefault
                }
                if {![array exists rss] || [array size rss] == 0} {
                        catch {array unset rss}
                        array set rss {}
                        dict for {feedName feedList} $fallbackFeeds {
                                set rss($feedName) $feedList
                        }
                }
                return
        }

        set tomlFile $settings(config-toml-file)
        if {$tomlFile eq ""} {
                set tomlFile [file join $scriptDir rss-set.toml]
        }
        set tomlFile [::rss-synd::resolve_path $tomlFile $scriptDir]
        set tomlExample [file normalize [file join $scriptDir rss-set.example.toml]]
        set usingExampleToml 0

        if {[catch {package require toml} err]} {
                ::rss-synd::use_fallback_config "\002RSS Fehler\002: toml-Paket nicht verfügbar ($err), nutze Tcl-Fallback."
                return
        }

        if {![file exists $tomlFile]} {
                if {$settings(config-toml-file) eq "" && [file exists $tomlExample]} {
                        set tomlFile $tomlExample
                        set usingExampleToml 1
                } else {
                        ::rss-synd::use_fallback_config "\002RSS Fehler\002: TOML-Datei '$tomlFile' nicht gefunden, nutze Tcl-Fallback."
                        return
                }
        }

        if {[catch {set parsed [::toml::parsefile $tomlFile]} err]} {
                ::rss-synd::use_fallback_config "\002RSS Fehler\002: TOML-Datei konnte nicht gelesen werden: $err"
                return
        }

        if {$usingExampleToml} {
                ::rss-synd::log_message warning "\002RSS Hinweis\002: Beispiel-TOML '$tomlFile' wird verwendet. Bitte nach 'rss-set.toml' kopieren und anpassen."
        }

        set defaultList {}
        if {[dict exists $parsed defaults]} {
                dict for {key value} [dict get $parsed defaults] {
                        lappend defaultList $key $value
                }
        }
        if {[llength $defaultList] == 0} {
                set defaultList $fallbackDefault
        }
        set default $defaultList

        catch {array unset rss}
        array set rss {}
        if {[dict exists $parsed feeds]} {
                dict for {feedName feedSpec} [dict get $parsed feeds] {
                        if {[dict size $feedSpec] == 0} {
                                continue
                        }
                        set feedList {}
                        dict for {key value} $feedSpec {
                                lappend feedList $key $value
                        }
                        set rss($feedName) $feedList
                }
        }
        if {[array size rss] == 0} {
                dict for {feedName feedList} $fallbackFeeds {
                        set rss($feedName) $feedList
                }
        }
}

proc ::rss-synd::configuration_to_dict {} {
        variable default
        variable rss
        variable fallbackDefault
        variable fallbackFeeds

        set defaultsList [expr {[info exists default] ? $default : $fallbackDefault}]
        if {[llength $defaultsList] % 2 != 0} {
                error "Ungültige Default-Liste: ungerade Anzahl an Elementen"
        }

        set defaultsDict [dict create]
        foreach {key value} $defaultsList {
                dict set defaultsDict $key $value
        }

        set feedsDict [dict create]
        if {![array exists rss] || [array size rss] == 0} {
                dict for {feedName feedSpec} $fallbackFeeds {
                        dict set feedsDict $feedName $feedSpec
                }
        } else {
                foreach feedName [lsort [array names rss]] {
                        set feedList $rss($feedName)
                        if {[llength $feedList] % 2 != 0} {
                                error "Ungültige Feed-Liste für '$feedName': ungerade Anzahl an Elementen"
                        }
                        set feedDict [dict create]
                        foreach {key value} $feedList {
                                dict set feedDict $key $value
                        }
                        dict set feedsDict $feedName $feedDict
                }
        }

        return [dict create defaults $defaultsDict feeds $feedsDict]
}

#
# Include Settings
#

::rss-synd::load_config

proc ::rss-synd::collect_tls_environment {{settingsList {}}} {
        variable default
        variable fallbackDefault
        variable scriptBaseDir
        variable packages

        set configList {}
        if {[llength $settingsList] > 0} {
                set configList $settingsList
        } elseif {[info exists default] && [llength $default] > 0} {
                set configList $default
        } else {
                set configList $fallbackDefault
        }

        array set cfg {}
        if {[llength $configList] > 0} {
                array set cfg $configList
        }

        if {[info exists scriptBaseDir] && $scriptBaseDir ne ""} {
                set baseDir $scriptBaseDir
        } else {
                set baseDir [file dirname [info script]]
        }

        set labelMap [dict create \
                tls-ca-file "CA-Datei" \
                tls-ca-dir "CA-Verzeichnis" \
                tls-cert-file "Client-Zertifikat" \
                tls-key-file "Client-Schlüssel"]
        set typeMap [dict create \
                tls-ca-file file \
                tls-ca-dir dir \
                tls-cert-file file \
                tls-key-file file]

        set optionInfo [dict create]
        set warnings {}

        dict for {key label} $labelMap {
                set type [dict get $typeMap $key]
                set configured 0
                set original ""
                set resolved ""
                set status "nicht gesetzt"
                set valid 0

                if {[info exists cfg($key)] && $cfg($key) ne ""} {
                        set configured 1
                        set original $cfg($key)
                        set resolved [::rss-synd::resolve_path $original $baseDir]
                        set status "ok"
                        set valid 1

                        if {![file exists $resolved]} {
                                set valid 0
                                set status "fehlt"
                                lappend warnings "$label '$resolved' wurde nicht gefunden."
                        } elseif {$type eq "dir" && ![file isdirectory $resolved]} {
                                set valid 0
                                set status "kein Verzeichnis"
                                lappend warnings "$label '$resolved' ist kein Verzeichnis."
                        } elseif {$type eq "file" && ![file isfile $resolved]} {
                                set valid 0
                                set status "keine Datei"
                                lappend warnings "$label '$resolved' ist keine Datei."
                        }

                        if {$valid && ![file readable $resolved]} {
                                set valid 0
                                set status "nicht lesbar"
                                lappend warnings "$label '$resolved' ist nicht lesbar."
                        }
                }

                set entry [dict create \
                        configured $configured \
                        original $original \
                        resolved $resolved \
                        status $status \
                        valid $valid \
                        type $type]
                dict set optionInfo $key $entry
        }

        set certInfo [dict get $optionInfo tls-cert-file]
        set keyInfo [dict get $optionInfo tls-key-file]
        if {[dict get $certInfo configured] && ![dict get $keyInfo configured]} {
                lappend warnings "Client-Zertifikat ist gesetzt, aber kein Client-Schlüssel angegeben."
        }
        if {[dict get $keyInfo configured] && ![dict get $certInfo configured]} {
                lappend warnings "Client-Schlüssel ist gesetzt, aber kein Client-Zertifikat angegeben."
        }

        set available 0
        if {[info exists packages] && [array exists packages] && [info exists packages(tls)]} {
                if {$packages(tls) == 0} {
                        set available 1
                }
        } elseif {[catch {package present tls}]} {
                # keep available 0
        } else {
                set available 1
        }

        set version ""
        if {$available} {
                if {[catch {package present tls} versionValue] == 0} {
                        set version $versionValue
                } elseif {[catch {package provide tls} provided] == 0 && $provided ne ""} {
                        set version $provided
                } elseif {[info commands ::tls::version] ne ""} {
                        set version [::tls::version]
                }
        } else {
                        lappend warnings "TLS-Paket 'tls' ist nicht verfügbar."
        }

        set summaryParts {}
        if {$available} {
                lappend summaryParts "Paket=verfügbar"
        } else {
                lappend summaryParts "Paket=fehlt"
        }
        if {$available && $version ne ""} {
                lappend summaryParts "Version=$version"
        }

        dict for {key label} $labelMap {
                set entry [dict get $optionInfo $key]
                lappend summaryParts "$label=[dict get $entry status]"
        }

        set summary [join $summaryParts ", "]

        set info [dict create]
        dict set info available $available
        dict set info version $version
        dict set info warnings $warnings
        dict set info paths $optionInfo
        dict set info summary $summary
        dict set info timestamp [clock seconds]

        return $info
}

proc ::rss-synd::tls_environment_check {{settingsList {}} {emitLogs 1}} {
        variable tlsStatus

        set info [::rss-synd::collect_tls_environment $settingsList]
        set tlsStatus $info

        if {$emitLogs} {
                ::rss-synd::log_message info "\002RSS TLS\002: [dict get $info summary]"
                foreach warn [dict get $info warnings] {
                        ::rss-synd::log_message warning "\002RSS Warnung\002: $warn"
                }
        }

        return $info
}

proc ::rss-synd::tls_socket {args} {
        variable tls
        if {[catch {::tls::socket {*}$args} socket options]} {
                ::rss-synd::log_message warning "\002RSS Warnung\002: TLS-Verbindung fehlgeschlagen: $socket"
                error $socket
	}
	return $socket
}

proc ::rss-synd::normalize_tls_options {options} {
	set normalized {}
	foreach {key value} $options {
		if {[string match "-tls1_*" $key]} {
			set key [string map {"-tls1_" "-tls1."} $key]
		}
		lappend normalized $key $value
	}
	return $normalized
}

proc ::rss-synd::setup_tls {{settingsList {}}} {
        variable tls
        variable debugOptions

        array set settings $settingsList

        set envInfo [::rss-synd::collect_tls_environment $settingsList]
        set optionInfo [dict get $envInfo paths]

        set customOptions {}
        set optionMap [list \
                tls-ca-file -cafile \
                tls-ca-dir -cadir \
                tls-cert-file -certfile \
                tls-key-file -keyfile]
        foreach {key optionName} $optionMap {
                if {![dict exists $optionInfo $key]} {
                        continue
                }
                set entry [dict get $optionInfo $key]
                if {[dict get $entry configured] && [dict get $entry resolved] ne ""} {
                        lappend customOptions $optionName [dict get $entry resolved]
                }
        }

        set allowLegacy [expr {[info exists settings(https-allow-legacy)] ? $settings(https-allow-legacy) : 0}]
        set tlsDebug [expr {[dict exists $debugOptions tls] ? [dict get $debugOptions tls] : 0}]
        set tlsDebugRequested $tlsDebug
        set tlsPrefix "\002RSS TLS Debug\002"

	if {$tlsDebug} {
		::rss-synd::log_message debug "$tlsPrefix: Initialisiere TLS (allow-legacy=$allowLegacy)"
	}

	if {[info exists tls(configured)]
			&& $tls(configured)
			&& [info exists tls(allowLegacy)]
			&& $tls(allowLegacy) == $allowLegacy} {
		return 1
	}

        set baseCore [list -require 1 -autoservername 1 -ssl2 0 -ssl3 0 -tls1 0 -tls1_1 0 -tls1_2 1]
        set baseOptions [concat $baseCore $customOptions]
        set modernOptions [concat $baseOptions [list -tls1_3 1]]
        set appliedOptions $modernOptions
        set optionsNormalized 0

	if {$tlsDebug} {
		::rss-synd::log_message debug "$tlsPrefix: Moderne Parameter: [join $modernOptions { }]"
	}

	set modernResult [catch {::tls::init {*}$modernOptions} modernErr]

	if {$modernResult != 0} {
		if {[string match "*bad option*" $modernErr] || [string match "*unknown option*" $modernErr]} {
			set baseOptions [::rss-synd::normalize_tls_options $baseOptions]
			set modernOptions [::rss-synd::normalize_tls_options $modernOptions]
			set appliedOptions $modernOptions
			set optionsNormalized 1

			if {$tlsDebug} {
				::rss-synd::log_message debug "$tlsPrefix: Normalisierte Optionen aufgrund von Kompatibilität"
			}

			set modernResult [catch {::tls::init {*}$modernOptions} modernErr]
		}
	}

	if {$modernResult != 0} {
		if {$tlsDebug} {
			::rss-synd::log_message debug "$tlsPrefix: Moderne TLS-Initialisierung schlug fehl: $modernErr"
		}

		::rss-synd::log_message error "\002RSS Fehler\002: TLS-Initialisierung (TLS 1.2/1.3) fehlgeschlagen: $modernErr"

		if {!$allowLegacy} {
			::rss-synd::log_message info "\002RSS Hinweis\002: Aktiviere 'https-allow-legacy' in den Einstellungen, um ältere Protokolle zu erlauben."
			return 0
		}

                set legacyCore [list -require 1 -autoservername 1 -ssl2 0 -ssl3 0 -tls1 1 -tls1_1 1 -tls1_2 1]
                set legacyOptions [concat $legacyCore $customOptions]
                if {$optionsNormalized} {
                        set legacyOptions [::rss-synd::normalize_tls_options $legacyOptions]
                }
		set appliedOptions $legacyOptions

		if {$tlsDebug} {
			::rss-synd::log_message debug "$tlsPrefix: Versuche Legacy-Parameter: [join $legacyOptions { }]"
		}

		if {[catch {::tls::init {*}$legacyOptions} legacyErr]} {
			::rss-synd::log_message error "\002RSS Fehler\002: TLS-Initialisierung im Legacy-Modus fehlgeschlagen: $legacyErr"
			return 0
		}

		::rss-synd::log_message warning "\002RSS Warnung\002: TLS nutzt Legacy-Protokolle, weil moderne Modi nicht unterstützt werden."
	}

	catch {::http::unregister https}
	if {[catch {::http::register https 443 [list ::rss-synd::tls_socket]} registerErr]} {
		::rss-synd::log_message error "\002RSS Fehler\002: HTTPS-Registrierung fehlgeschlagen: $registerErr"
		return 0
	}

	set tls(configured) 1
	set tls(allowLegacy) $allowLegacy

	if {$tlsDebug} {
		::rss-synd::log_message debug "$tlsPrefix: TLS-Stack erfolgreich initialisiert"
	}

	if {$tlsDebugRequested} {
		set optionParts {}
		if {[expr {[llength $appliedOptions] % 2}] == 0} {
			foreach {key value} $appliedOptions {
				lappend optionParts "$key $value"
			}
		}

		if {[llength $optionParts] == 0} {
			if {[llength $appliedOptions] == 0} {
				set optionText "keine"
			} else {
				set optionText [join $appliedOptions { }]
			}
		} else {
			set optionText [join $optionParts ", "]
		}

		if {[info command ::tls::debug] ne ""} {
			if {[catch {::tls::debug 1} dbgErr]} {
				::rss-synd::log_message warning "\002RSS Warnung\002: TLS-Debugausgabe konnte nicht aktiviert werden: $dbgErr"
			} else {
				::rss-synd::log_message info "\002RSS Debug\002: TLS-Debugausgabe über ::tls::debug aktiviert (Optionen: $optionText)."
			}
		} else {
			::rss-synd::log_message info "\002RSS Debug\002: TLS-Debugmodus angefordert, ::tls::debug nicht verfügbar."
			::rss-synd::log_message info "\002RSS Debug\002: Verwendete TLS-Handshake-Optionen: $optionText."
		}
	}

	return 1
}

proc ::rss-synd::init {args} {
	variable rss
	variable default
	variable version
	variable packages
	variable settings

	set version(number)	git-pubdate
	set version(date)	"2025-10-18"

        package require http
        set packages(base64) [catch {package require base64}]; # http auth
        set packages(tls) [catch {package require tls}]; # https
        set packages(trf) [catch {package require Trf}]; # gzip compression
        set packages(uri) [catch {package require uri}]; # URL-Auflösung

        if {[info exists settings] && [array exists settings]} {
        ::rss-synd::configure_debug [array get settings]
        } else {
        ::rss-synd::configure_debug
        }
        ::rss-synd::configure_logging
        ::rss-synd::tls_environment_check

        foreach feed [array names rss] {
                array set tmp $default
                array set tmp $rss($feed)

		set required [list "announce-output" "trigger-output" "max-depth" "update-interval" "timeout" "channels" "output" "user-agent" "url" "database" "trigger-type" "announce-type"]
		foreach {key value} [array get tmp] {
			if {[set ptr [lsearch -exact $required $key]] >= 0} {
				set required [lreplace $required $ptr $ptr]
			}
		}

		if {[llength $required] == 0} {
			regsub -nocase -all -- {@@feedid@@} $tmp(trigger) $feed tmp(trigger)

			set ulist [regexp -nocase -inline -- {(http(?:s?))://(?:(.[^:]+:.[^@]+)?)(?:@?)(.*)} $tmp(url)]

                        if {[llength $ulist] == 0} {
                                ::rss-synd::log_message error "\002RSS Error\002: Unable to parse URL, Invalid format for feed \"$feed\"."
				unset rss($feed)
				continue
			}

			set tmp(url) "[lindex $ulist 1]://[lindex $ulist 3]"

                        if {[lindex $ulist 1] == "https"} {
                                if {$packages(tls) != 0} {
                                        ::rss-synd::log_message error "\002RSS Error\002: Unable to find tls package required for https, unloaded feed \"$feed\"."
                                        unset rss($feed)
                                        continue
                                }

                                if {![::rss-synd::setup_tls [array get tmp]]} {
                                        ::rss-synd::log_message error "\002RSS Error\002: TLS-Konfiguration für Feed \"$feed\" fehlgeschlagen. HTTPS wird deaktiviert."
                                        unset rss($feed)
                                        continue
                                }
                        }

			if {(![info exists tmp(url-auth)]) || ($tmp(url-auth) == "")} {
				set tmp(url-auth) ""

				if {[lindex $ulist 2] != ""} {
                                        if {$packages(base64) != 0} {
                                                ::rss-synd::log_message error "\002RSS Error\002: Unable to find base64 package required for http authentication, unloaded feed \"$feed\"."
						unset rss($feed)
						continue
					}

					set tmp(url-auth) [::base64::encode [lindex $ulist 2]]
				}
			}

                        if {[regexp {^[0123]{1}:[0123]{1}$} $tmp(trigger-type)] != 1} {
                                ::rss-synd::log_message error "\002RSS Error\002: Invalid 'trigger-type' syntax for feed \"$feed\"."
				unset rss($feed)
				continue
			}

			set tmp(trigger-type) [split $tmp(trigger-type) ":"]

                        if {([info exists tmp(charset)]) && ([lsearch -exact [encoding names] [string tolower $tmp(charset)]] < 0)} {
                                ::rss-synd::log_message error "\002RSS Error\002: Unable to load feed \"$feed\", unknown encoding \"$tmp(charset)\"."
				unset rss($feed)
				continue
			}
			
                        if {([info exists tmp(feedencoding)]) && ([lsearch -exact [encoding names] [string tolower $tmp(feedencoding)]] < 0)} {
                                ::rss-synd::log_message error "\002RSS Error\002: Unable to load feed \"$feed\", unknown feedencoding \"$tmp(feedencoding)\"."
				unset rss($feed)
				continue
			}

			set tmp(updated) 0
			if {([file exists $tmp(database)]) && ([set mtime [file mtime $tmp(database)]] < [unixtime])} {
				set tmp(updated) [file mtime $tmp(database)]
			}

			set rss($feed) [array get tmp]
                } else {
                        ::rss-synd::log_message error "\002RSS Error\002: Unable to load feed \"$feed\", missing one or more required settings. \"[join $required ", "]\""
			unset rss($feed)
		}

		unset tmp
	}

        bind evnt -|- prerehash [namespace current]::deinit
        bind time -|- {* * * * *} [namespace current]::feed_get
        bind pubm -|- {* *} [namespace current]::trigger
        bind msgm -|- {*} [namespace current]::trigger
        bind dcc -|- rss [namespace current]::dcc_fetch
        bind dcc -|- tlscheck [namespace current]::dcc_tls_check

        ::rss-synd::log_message info "\002RSS Syndication Script v$version(number)\002 ($version(date)): Loaded."
}

proc ::rss-synd::deinit {args} {
        catch {unbind evnt -|- prerehash [namespace current]::deinit}
        catch {unbind time -|- {* * * * *} [namespace current]::feed_get}
        catch {unbind pubm -|- {* *} [namespace current]::trigger}
        catch {unbind msgm -|- {*} [namespace current]::trigger}
        catch {unbind dcc -|- rss [namespace current]::dcc_fetch}
        catch {unbind dcc -|- tlscheck [namespace current]::dcc_tls_check}

        ::rss-synd::flush_log_queue

        foreach child [namespace children] {
                catch {[set child]::deinit}
        }

        namespace delete [namespace current]
}

#
# DCC-Kommandos
#

proc ::rss-synd::dcc_tls_check {handle idx text} {
        set status [::rss-synd::tls_environment_check {} 0]
        set summary [dict get $status summary]
        putdcc $idx "TLS-Check: $summary"

        set labelMap [dict create \
                tls-ca-file "CA-Datei" \
                tls-ca-dir "CA-Verzeichnis" \
                tls-cert-file "Client-Zertifikat" \
                tls-key-file "Client-Schlüssel"]

        set paths [dict get $status paths]
        dict for {key label} $labelMap {
                if {![dict exists $paths $key]} {
                        continue
                }
                set entry [dict get $paths $key]
                if {[dict get $entry configured]} {
                        set resolved [dict get $entry resolved]
                        set statusLabel [dict get $entry status]
                        if {$resolved eq ""} {
                                set message "$label: konfiguriert ($statusLabel)"
                        } else {
                                set message "$label: $resolved ($statusLabel)"
                        }
                } else {
                        set message "$label: nicht gesetzt"
                }
                putdcc $idx $message
        }

        set warnings [dict get $status warnings]
        if {[llength $warnings] == 0} {
                putdcc $idx "Keine TLS-Warnungen."
        } else {
                foreach warn $warnings {
                        putdcc $idx "Warnung: $warn"
                }
        }
}

#
# Trigger Function
##

proc ::rss-synd::trigger {nick user handle args} {
        variable rss
        variable default

	set i 0
	set chan ""
	if {[llength $args] == 2} {
		set chan [lindex $args 0]
		incr i
	}
	set text [lindex $args $i]

	array set tmp $default

	if {[info exists tmp(trigger)]} {
		regsub -all -- {@@(.*?)@@} $tmp(trigger) "" tmp_trigger
		set tmp_trigger [string trimright $tmp_trigger]

		if {[string equal -nocase $text $tmp_trigger]} {
			set list_feeds [list]
		}
	}

	unset -nocomplain tmp tmp_trigger

	foreach name [array names rss] {
		array set feed $rss($name)

		if {(![info exists list_feeds]) && \
		    ([string equal -nocase $text $feed(trigger)])} {
			if {(![[namespace current]::check_channel $feed(channels) $chan]) && \
			    ([string length $chan] != 0)} {
				continue
			}

			set feed(nick) $nick

			if {$chan != ""} {
				set feed(type) [lindex $feed(trigger-type) 0]
				set feed(channels) $chan
			} else {
				set feed(type) [lindex $feed(trigger-type) 1]
				set feed(channels) ""
			}

                        set fetchMode none
                        if {[info exists feed(trigger-fetch)]} {
                                set fetchMode [string tolower $feed(trigger-fetch)]
                        }

                        switch -glob -- $fetchMode {
                                {force} - {1} - {true} - {yes} {
                                        set fetchResult [[namespace current]::start_feed_fetch $name force trigger]
                                }
                                {due} - {interval} - {2} {
                                        set fetchResult [[namespace current]::start_feed_fetch $name due trigger]
                                }
                                default {
                                        set fetchResult [dict create status skipped reason disabled]
                                }
                        }

                        if {[dict get $fetchResult status] eq "error"} {
                                ::rss-synd::log_message error "\002RSS HTTP Fehler\002: Trigger-Abruf für \"$name\" scheiterte: [dict get $fetchResult message]"
                        } elseif {[dict get $fetchResult status] eq "skipped" && [dict exists $fetchResult message]} {
                                ::rss-synd::log_message debug "RSS Debug Trigger: Abruf für '$name' übersprungen – [dict get $fetchResult message]"
                        }

                        if {[catch {set data [[namespace current]::feed_read]} error] == 0} {
                                if {![[namespace current]::feed_info $data]} {
                                        ::rss-synd::log_message error "\002RSS Error\002: Invalid feed database file format ($feed(database))!"
                                        return
				}

				if {$feed(trigger-output) > 0} {
					set feed(announce-output) $feed(trigger-output)

					[namespace current]::feed_output $data
				}
                        } else {
                                ::rss-synd::log_message warning "\002RSS Warning\002: $error."
			}
		} elseif {[info exists list_feeds]} {
			if {$chan != ""} {
				# triggered from a channel
				if {[[namespace current]::check_channel $feed(channels) $chan]} {
					lappend list_feeds $feed(trigger)
				}
			} else {
				# triggered from a privmsg
				foreach tmp_chan $feed(channels) {
					if {([catch {botonchan $tmp_chan}] == 0) && \
					    ([onchan $nick $tmp_chan])} {
						lappend list_feeds $feed(trigger)
						continue
					}
				}
			}
		}
	}

	if {[info exists list_feeds]} {
		if {[llength $list_feeds] == 0} {
			lappend list_feeds "None"
		}

		lappend list_msgs "Available feeds: [join $list_feeds ", "]."

		if {$chan != ""} {
			set list_type [lindex $feed(trigger-type) 0]
			set list_targets $chan
		} else {
			set list_type [lindex $feed(trigger-type) 1]
			set list_targets ""
		}

		[namespace current]::feed_msg $list_type $list_msgs list_targets $nick
        }
}


proc ::rss-synd::next_user_agent {name feedVar} {
        upvar 1 $feedVar feed

        set now [clock seconds]

        set rotation ""
        if {[info exists feed(user-agent-rotate)] && $feed(user-agent-rotate) ne ""} {
                set rotation $feed(user-agent-rotate)
        }

        set fallbackRaw ""
        if {[info exists feed(user-agent)] && $feed(user-agent) ne ""} {
                set fallbackRaw $feed(user-agent)
        }

        set parsedFallback {}
        if {$fallbackRaw ne ""} {
                if {[catch {llength $fallbackRaw}]} {
                        set parsedFallback [list $fallbackRaw]
                } else {
                        set parsedFallback [lrange $fallbackRaw 0 end]
                }
        }

        if {[string equal -nocase $rotation "list"]} {
                set pool $parsedFallback
        } else {
                if {[llength $parsedFallback] > 0} {
                        set pool [list [lindex $parsedFallback 0]]
                } else {
                        set pool {}
                }
        }

        set fallback ""
        if {[llength $parsedFallback] > 0} {
                set fallback [lindex $parsedFallback 0]
        }

        set chosen ""
        if {$rotation eq ""} {
                set chosen $fallback
        } elseif {[string equal -nocase $rotation "list"]} {
                if {[llength $pool] == 0} {
                        ::rss-synd::log_message warning "\002RSS Warnung\002: User-Agent-Rotation für Feed \"$name\" ist aktiviert, aber es sind keine Kandidaten hinterlegt."
                } else {
                        set idxKey user-agent-rotate-index
                        if {![info exists feed($idxKey)] || ![string is integer -strict $feed($idxKey)]} {
                                set feed($idxKey) 0
                        }
                        set poolSize [llength $pool]
                        if {$poolSize <= 0} {
                                set chosen $fallback
                        } else {
                                set currentIdx $feed($idxKey)
                                if {$currentIdx < 0 || $currentIdx >= $poolSize} {
                                        set currentIdx [expr {(($currentIdx % $poolSize) + $poolSize) % $poolSize}]
                                }
                                set chosen [lindex $pool $currentIdx]
                                set feed($idxKey) [expr {($currentIdx + 1) % $poolSize}]
                        }
                }
        } else {
                if {[catch {set command [lrange $rotation 0 end]}]} {
                        set command [list $rotation]
                }
                set invoke [concat $command [list $name [array get feed]]]
                if {[catch {set result [uplevel #0 $invoke]} err]} {
                        ::rss-synd::log_message warning "\002RSS Warnung\002: Benutzerdefinierte User-Agent-Rotation für Feed \"$name\" schlug fehl: $err"
                } else {
                        set isDict [expr {[string is list -strict $result] && ([llength $result] % 2) == 0}]
                        if {$isDict && [dict exists $result user-agent]} {
                                set chosen [dict get $result user-agent]
                                dict for {key value} $result {
                                        if {$key eq "user-agent"} {
                                                continue
                                        }
                                        set feed($key) $value
                                }
                        } elseif {$result ne ""} {
                                set chosen $result
                        }
                }
        }

        if {$chosen eq ""} {
                set chosen $fallback
        }

        set feed(user-agent-last) $now
        return $chosen
}

proc ::rss-synd::start_feed_fetch {name {mode due} {origin auto}} {
	variable rss
	variable debugOptions

	if {![info exists rss($name)]} {
		return [dict create status error message "Feed \"$name\" nicht gefunden"]
	}

	array set feed $rss($name)

	set normalized [string tolower $mode]
	set forceFetch [expr {$normalized in {force immediate 1 true yes}}]

	set now [unixtime]
	set intervalSeconds [expr {$feed(update-interval) * 60}]
	set due [expr {$feed(updated) <= ($now - $intervalSeconds)}]

        if {!$forceFetch && !$due} {
                return [dict create status skipped reason interval message "Abrufintervall für \"$name\" noch nicht abgelaufen"]
        }

	set userAgent [next_user_agent $name feed]
	::http::config -useragent $userAgent

	set feed(type) $feed(announce-type)
	set feed(headers) [list]

	if {$feed(url-auth) ne ""} {
		lappend feed(headers) Authorization "Basic $feed(url-auth)"
	}

	if {[info exists feed(enable-gzip)] && $feed(enable-gzip)} {
		lappend feed(headers) "Accept-Encoding" "gzip"
	}

	set callbackData [concat [array get feed] [list feed-name $name depth 0 fetch-origin $origin]]

	set headerSummary "keine"
	if {[llength $feed(headers)] > 0} {
		set headerPairs {}
		foreach {hKey hValue} $feed(headers) {
			lappend headerPairs "$hKey: $hValue"
		}
                set headerSummary [join $headerPairs ", "]
	}

        if {[dict exists $debugOptions http] && [dict get $debugOptions http]} {
                ::rss-synd::log_message debug [format "\002RSS Debug HTTP\002: Feed '%s' -> GET %s (User-Agent: %s; Header: %s; Origin: %s)" $name $feed(url) $userAgent $headerSummary $origin]
        }

	set result [catch {::http::geturl $feed(url) -command [list [namespace current]::feed_callback $callbackData] -timeout $feed(timeout) -headers $feed(headers)} token]

	if {$result != 0} {
		return [dict create status error message $token]
	}

	if {[dict exists $debugOptions http] && [dict get $debugOptions http]} {
		set headerText [::rss-synd::format_header_debug $feed(headers)]
                ::rss-synd::log_message info [format "\002RSS Debug\002: HTTP-Abruf für '%s' (Timeout: %s ms, Header: %s)" $feed(url) $feed(timeout) $headerText]
	}

	set feed(updated) $now
	set rss($name) [array get feed]

	return [dict create status started]
}


proc ::rss-synd::feed_get {args} {
	variable rss

	set i 0
	foreach name [array names rss] {
		if {$i == 3} { break }

		set fetchInfo [[namespace current]::start_feed_fetch $name due auto]

		switch -- [dict get $fetchInfo status] {
			started {
				incr i
			}
			error {
				::rss-synd::log_message error "RSS HTTP Fehler: Anfrage für \"$name\" konnte nicht gestartet werden: [dict get $fetchInfo message]"
			}
		}
	}
}


proc ::rss-synd::dcc_fetch {handle idx text} {
	variable rss

	set trimmed [string trim $text]
	if {$trimmed eq ""} {
		putdcc $idx "Verwendung: rss <Feedname> [force]"
		return
	}

	set parts [split $trimmed]
	set feedArg [lindex $parts 0]
	set modeArg [string tolower [lindex $parts 1]]

	set target ""
	foreach name [array names rss] {
		if {[string equal -nocase $name $feedArg]} {
			set target $name
			break
		}
	}

	if {$target eq ""} {
		putdcc $idx "Unbekannter Feed: $feedArg"
		return
	}

	set mode due
	if {$modeArg in {force sofort now sofort! true yes 1}} {
		set mode force
	}

	set fetchInfo [[namespace current]::start_feed_fetch $target $mode dcc]
	set status [dict get $fetchInfo status]

	switch -- $status {
		started {
			putdcc $idx "HTTP-Abruf für '$target' gestartet."
			::rss-synd::log_message info "\002RSS\002: DCC-Trigger von $handle für '$target' gestartet (Modus: $mode)."
		}
                skipped {
                        set reason "keine Aktion"
                        if {[dict exists $fetchInfo message]} {
                                set reason [dict get $fetchInfo message]
                        } elseif {[dict exists $fetchInfo reason]} {
                                set reason [dict get $fetchInfo reason]
                        }
                        if {[string equal -nocase $reason "disabled"]} {
                                set reason "Trigger-Fetch deaktiviert"
                        }
                        putdcc $idx "Abruf für '$target' übersprungen: $reason."
                        ::rss-synd::log_message info "\002RSS\002: DCC-Trigger von $handle für '$target' übersprungen ($reason)."
                }
		error {
			set err [dict get $fetchInfo message]
			putdcc $idx "Abruf für '$target' fehlgeschlagen: $err"
			::rss-synd::log_message error "\002RSS HTTP Fehler\002: DCC-Abruf für '$target' scheiterte: $err"
		}
	}
}





proc ::rss-synd::feed_callback {feedlist args} {
        set token [lindex $args end]
        array set feed $feedlist
        variable packages
        variable debugOptions

        upvar 0 $token state

        set feedName "unbekannt"
        if {[info exists feed(feed-name)] && $feed(feed-name) ne ""} {
                set feedName $feed(feed-name)
        }

        set debugHttp [expr {[dict exists $debugOptions http] ? [dict get $debugOptions http] : 0}]
        set debugRedirect [expr {[dict exists $debugOptions redirect] ? [dict get $debugOptions redirect] : 0}]

        upvar #0 $token state

        if {[set status $state(status)] != "ok"} {
                if {$status == "error"} { set status $state(error) }
                ::rss-synd::log_message error "RSS HTTP Error: $state(url) (State: $status)"
                ::http::cleanup $token
                return 1
        }

        array set meta $state(meta)

        if {$debugHttp} {
                set httpCode [::http::ncode $token]
                set httpStatus ""
                if {[info exists state(http)]} {
                        set httpStatus $state(http)
                }
                ::rss-synd::log_message debug [format "RSS Debug HTTP: Feed '%s' <- %s (Status: %s; Code: %s)" $feedName $state(url) $httpStatus $httpCode]
        }

        if {([::http::ncode $token] == 302) || ([::http::ncode $token] == 301)} {
                set feed(depth) [expr {$feed(depth) + 1 }]

                if {$feed(depth) < $feed(max-depth)} {
                        if {![info exists meta(Location)] || $meta(Location) eq ""} {
                                ::rss-synd::log_message error "RSS HTTP Error: $state(url) (State: Redirect ohne Location-Header)"
                        } else {
                                set base $state(url)
                                if {[catch {set redirectUrl [[namespace current]::resolve_redirect $base $meta(Location)]} redirectErr]} {
                                        ::rss-synd::log_message error "RSS HTTP Error: Weiterleitung für "$state(url)" fehlgeschlagen: $redirectErr"
                                } else {
                                        if {$debugRedirect} {
                                                ::rss-synd::log_message debug [format "RSS Debug Redirect: Feed '%s' folgt %s -> %s" $feedName $state(url) $redirectUrl]
                                        }
                                        set callbackList [array get feed]
                                        set redirectOptions [list -command [list [namespace current]::feed_callback $callbackList] -timeout $feed(timeout) -headers $feed(headers)]
                                        namespace eval ::http { variable lastRedirectArgs }
                                        set ::http::lastRedirectArgs [list $redirectUrl $redirectOptions]
                                        set redirectResult [catch {::http::geturl $redirectUrl {*}$redirectOptions} redirectToken]
                                        if {$redirectResult != 0} {
                                                ::rss-synd::log_message error "\002RSS HTTP Fehler\002: Weiterleitungsabruf von \"$redirectUrl\" scheiterte: $redirectToken"
                                        } elseif {[dict exists $debugOptions http] && [dict get $debugOptions http]} {
                                                set headerText [::rss-synd::format_header_debug $feed(headers)]
                                                ::rss-synd::log_message info [format "\002RSS Debug\002: HTTP-Redirect-Abruf für '%s' (Timeout: %s ms, Header: %s)" $redirectUrl $feed(timeout) $headerText]
                                        }
                                }
                        }
                } else {
                        ::rss-synd::log_message error "RSS HTTP Error: $state(url) (State: timeout, max refer limit reached)"
                }

                ::http::cleanup $token
                return 1
        } elseif {[::http::ncode $token] != 200} {
                ::rss-synd::log_message error "RSS HTTP Error: $state(url) ($state(http))"
                ::http::cleanup $token
                return 1
        }

        set data [::http::data $token]

        if {[info exists feed(feedencoding)]} {
                set data [encoding convertfrom [string tolower $feed(feedencoding)] $data]
        }

        if {[info exists feed(charset)]} {
                if {[string tolower $feed(charset)] == "utf-8" && [is_utf8_patched]} {
                        #do nothing, already utf-8
                } else {
                        set data [encoding convertto [string tolower $feed(charset)] $data]
                }
        }

        if {([info exists meta(Content-Encoding)]) &&             ([string equal $meta(Content-Encoding) "gzip"])} {
                if {[catch {[namespace current]::feed_gzip $data} data] != 0} {
                        ::rss-synd::log_message error "RSS Error: Unable to decompress "$state(url)": $data"
                        ::http::cleanup $token
                        return 1
                }
        }

        if {[catch {[namespace current]::xml_list_create $data} data] != 0} {
                ::rss-synd::log_message error "RSS Error: Unable to parse feed properly, parser returned error. "$state(url)""
                ::http::cleanup $token
                return 1
        }

        if {[string length $data] == 0} {
                ::rss-synd::log_message error "RSS Error: Unable to parse feed properly, no data returned. "$state(url)""
                ::http::cleanup $token
                return 1
        }

        set odata ""
        if {[catch {set odata [[namespace current]::feed_read]} error] != 0} {
                ::rss-synd::log_message warning "RSS Warning: $error."
        }

        if {![[namespace current]::feed_info $data]} {
                ::rss-synd::log_message error "RSS Error: Invalid feed format ($state(url))!"
                ::http::cleanup $token
                return 1
        }

        set max_items [expr {int(max($feed(announce-output), $feed(trigger-output)))}]
        set data [[namespace current]::feed_trim $data feed $max_items]

        if {$odata ne ""} {
                set odata [[namespace current]::feed_trim $odata feed $max_items]
        }

        ::http::cleanup $token

        if {[catch {[namespace current]::feed_write $data} error] != 0} {
                ::rss-synd::log_message error "RSS Database Error: $error."
                return 1
        }

        if {$feed(announce-output) > 0} {
                [namespace current]::feed_output $data $odata
        }
}
proc ::rss-synd::feed_info {data {target "feed"}} {
	upvar 1 $target feed
	set length [[namespace current]::xml_get_info $data [list -1 "*"]]

	for {set i 0} {$i < $length} {incr i} {
		set type [[namespace current]::xml_get_info $data [list $i "*"] "name"]

		# tag-name: the name of the element that contains each article and its data
		# tag-list: the position in the xml structure where all 'tag-name' reside
		switch [string tolower $type] {
			rss {
				# RSS v0.9x & x2.0
				set feed(tag-list) [list 0 "channel"]
				set feed(tag-name) "item"
				break
			}
			rdf:rdf {
				# RSS v1.0
				set feed(tag-list) [list]
				set feed(tag-name) "item"
				break
			}
			feed {
				# ATOM
				set feed(tag-list) [list]
				set feed(tag-name) "entry"
				break
			}
		}
	}

	if {![info exists feed(tag-list)]} {
		return 0
	}

	set feed(tag-feed) [list 0 $type]

	return 1
}

# decompress gzip formatted data
proc ::rss-synd::feed_gzip {cdata} {
	variable packages

	if {(![info exists packages(trf)]) || \
	    ($packages(trf) != 0)} {
		error "Trf package not found."
	}

	# remove the 10 byte gzip header and 8 byte footer
	set cdata [string range $cdata 10 [expr { [string length $cdata] - 9 } ]]

	# decompress the raw data
	if {[catch {zip -mode decompress -nowrap 1 $cdata} data] != 0} {
		error $data
	}

	return $data
}

proc ::rss-synd::feed_read { } {
	upvar 1 feed feed

	if {[catch {open $feed(database) "r"} fp] != 0} {
		error $fp
	}

	set data [read -nonewline $fp]

	close $fp

	return $data
}

proc ::rss-synd::feed_write {data} {
        upvar 1 feed feed

        if {[catch {open $feed(database) "w+"} fp] != 0} {
                error $fp
        }

        set data [string map { "\n" "" "\r" "" } $data]

        puts -nonewline $fp $data

        close $fp
}

proc ::rss-synd::feed_trim {data feedName max_items} {
        if {$data eq ""} {
                return $data
        }

        if {$max_items < 0} {
                return $data
        }

        set max_items [expr {int($max_items)}]

        upvar 1 $feedName feed

        if {![info exists feed(tag-feed)] || ![info exists feed(tag-list)] || ![info exists feed(tag-name)]} {
                return $data
        }

        set path [[namespace current]::xml_join_tags $feed(tag-feed) $feed(tag-list)]

        return [[namespace current]::xml_trim_to_limit $data $path $feed(tag-name) $max_items]
}

proc ::rss-synd::xml_trim_to_limit {xml_list path tag_name max_items} {
        if {$max_items < 0} {
                return $xml_list
        }

        if {$xml_list eq ""} {
                return $xml_list
        }

        if {[llength $path] == 0} {
                return [[namespace current]::xml_limit_children $xml_list $tag_name $max_items]
        }

        set index_target [lindex $path 0]
        set name_target [lindex $path 1]
        set rest [lrange $path 2 end]
        set match_index 0
        set result [list]

        foreach element $xml_list {
                if {[catch {array set node $element}]} {
                        lappend result $element
                        continue
                }

                set should_process 0
                if {[info exists node(name)] && [string match -nocase $name_target $node(name)]} {
                        if {$index_target == -1 || $match_index == $index_target} {
                                set should_process 1
                        }

                        incr match_index
                }

                if {$should_process && [info exists node(children)]} {
                        set node(children) [[namespace current]::xml_trim_to_limit $node(children) $rest $tag_name $max_items]
                }

                lappend result [array get node]
                unset node
        }

        return $result
}

proc ::rss-synd::xml_limit_children {xml_list tag_name max_items} {
        if {$max_items < 0} {
                return $xml_list
        }

        set max_items [expr {int($max_items)}]

        set result [list]
        set kept 0

        foreach element $xml_list {
                if {[catch {array set node $element}]} {
                        lappend result $element
                        continue
                }

                if {[info exists node(name)] && [string match -nocase $tag_name $node(name)]} {
                        incr kept
                        if {$kept > $max_items} {
                                unset node
                                continue
                        }
                }

                lappend result [array get node]
                unset node
        }

        return $result
}

proc ::rss-synd::resolve_redirect {base location} {
        variable packages

        if {![info exists packages(uri)]} {
                set packages(uri) [catch {package require uri}]
        }

        if {[string match -nocase {http://*} $location] || [string match -nocase {https://*} $location]} {
                return $location
        }

        if {![info exists base] || $base eq ""} {
                return $location
        }

        if {[info exists packages(uri)] && $packages(uri) == 0} {
                if {![catch {uri::resolve $base $location} resolved]} {
                        return $resolved
                }
        }

        # einfache Fallback-Auflösung ohne uri::resolve
        if {[regexp -nocase {^(https?://[^/]+)(/.*)?$} $base -> prefix pathPart]} {
                if {$location eq ""} {
                        return $base
                }

                if {[string match "/*" $location]} {
                        return "$prefix$location"
                }

                if {$pathPart eq ""} {
                        set pathSegments [list ""]
                } else {
                        set pathSegments [split $pathPart "/"]
                }

                if {[llength $pathSegments] > 1} {
                        set pathSegments [lrange $pathSegments 0 end-1]
                }

                foreach segment [split $location "/"] {
                        if {$segment eq "" || $segment eq "."} {
                                continue
                        } elseif {$segment eq ".."} {
                                if {[llength $pathSegments] > 1} {
                                        set pathSegments [lrange $pathSegments 0 end-1]
                                }
                        } else {
                                lappend pathSegments $segment
                        }
                }

                set joined [join $pathSegments "/"]
                if {$joined eq ""} {
                        set joined "/"
                } elseif {[string index $joined 0] ne "/"} {
                        set joined "/$joined"
                }

                return "$prefix$joined"
        }

        return $location
}

#
# XML Functions
##

proc ::rss-synd::xml_list_create {xml_data {start 0} {end -1}} {
        set ns_current [namespace current]
        set xml_list [list]

        set length [string length $xml_data]
        if {$length == 0} {
                return $xml_list
        }

        if {$start < 0} {
                set start 0
        }
        if {$end < 0 || $end >= $length} {
                set end [expr {$length - 1}]
        }
        if {$start > $end} {
                return $xml_list
        }

        set ptr $start

        while {$ptr <= $end} {
                set tag_start [${ns_current}::xml_get_position $xml_data $ptr $end]
                if {$tag_start eq ""} {
                        break
                }

                set tag_start_first [lindex $tag_start 0]
                if {$tag_start_first > $end} {
                        break
                }

                set tag_start_last [lindex $tag_start 1]

                set data_start $ptr
                set data_end [expr {$tag_start_first - 2}]
                if {$data_end >= $data_start && $data_start <= $end} {
                        if {$data_start < $start} {
                                set data_start $start
                        }
                        if {$data_end > $end} {
                                set data_end $end
                        }
                        if {$data_end >= $data_start} {
                                lappend xml_list [list "data" [${ns_current}::xml_escape [string range $xml_data $data_start $data_end]]]
                        }
                }

                set tag_string [string range $xml_data $tag_start_first $tag_start_last]
                set ptr [expr {$tag_start_last + 2}]
                array set tag [list]

                if {[regexp -nocase -- {^!(\[CDATA|--|DOCTYPE)} $tag_string]} {
                        set tag_data $tag_string

                        regexp -nocase -- {^!\[CDATA\[(.*?)\]\]$} $tag_string -> tag_data
                        regexp -nocase -- {^!--(.*?)--$} $tag_string -> tag_data

                        if {[info exists tag_data]} {
                                set tag(data) [${ns_current}::xml_escape $tag_data]
                        }
                } else {
                        if {[string match {[/]*} $tag_string]} {
                                ::rss-synd::log_message error "\002RSS Malformed Feed\002: Tag not open: \"<$tag_string>\" ($tag_start_first => $tag_start_last)"
                                unset tag
                                continue
                        }

                        regexp -- {(.[^ \/\n\r]*)(?: |\n|\r\n|\r|)(.*?)$} $tag_string -> tag_name tag_args
                        set tag(name) [${ns_current}::xml_escape $tag_name]

                        set tag(attrib) [list]
                        if {[string length $tag_args] > 0} {
                                set values [regexp -inline -all -- {(?:\s*|)(.[^=]*)=["'](.[^"']*)["']} $tag_args]

                                foreach {r_match r_tag r_value} $values {
                                        lappend tag(attrib) [${ns_current}::xml_escape $r_tag] [${ns_current}::xml_escape $r_value]
                                }
                        }

                        if {(![regexp {(\?|!|/)(\s*)$} $tag_args]) || (![string match "\?*" $tag_string])} {
                                set tmp_num 1
                                set tag_success 0
                                set tag_end_last $ptr

                                while {$tmp_num > 0} {
                                        set tag_success [regexp -indices -start $tag_end_last -- "</$tag_name>" $xml_data tag_end]

                                        if {!$tag_success || [lindex $tag_end 0] == -1 || ([lindex $tag_end 0] > $end)} {
                                                set tag_success 0
                                                break
                                        }

                                        set last_tag_end_last $tag_end_last

                                        set tag_end_first [lindex $tag_end 0]
                                        set tag_end_last [lindex $tag_end 1]

                                        set search_end [expr {$tag_end_last < $end ? $tag_end_last : $end}]
                                        incr tmp_num [regexp -all -- "<$tag_name\(\[\\s\\t\\n\\r\]+\(\[^/>\]*\)?\)?>" [string range $xml_data $last_tag_end_last $search_end]]
                                        incr tmp_num -1
                                }

                                if {$tag_success == 0} {
                                        ::rss-synd::log_message error "\002RSS Malformed Feed\002: Tag not closed: \"<$tag_name>\""
                                        return
                                }

                                set ptr [expr {$tag_end_last + 1}]
                                set child_start [expr {$tag_start_last + 2}]
                                set child_end [expr {$tag_end_first - 1}]

                                if {$child_end >= $child_start} {
                                        set result [${ns_current}::xml_list_create $xml_data $child_start $child_end]
                                } else {
                                        set result [list]
                                }

                                if {[llength $result] > 0} {
                                        set tag(children) $result
                                } else {
                                        if {$child_end >= $child_start} {
                                                set tag(data) [${ns_current}::xml_escape [string range $xml_data $child_start $child_end]]
                                        } else {
                                                set tag(data) ""
                                        }
                                }
                        }
                }

                lappend xml_list [array get tag]
                unset tag
        }

        if {$ptr <= $end} {
                lappend xml_list [list "data" [${ns_current}::xml_escape [string range $xml_data $ptr $end]]]
        }

        return $xml_list
}

# simple escape function
proc ::rss-synd::xml_escape {string} {
	regsub -all -- {([\{\}])} $string {\\\1} string

	return $string
}

# this function is to replace:
#  regexp -indices -start $ptr {<(!\[CDATA\[.+?\]\]|!--.+?--|!DOCTYPE.+?|.+?)>} $xml_data -> tag_start
# which doesnt work correctly with tcl's re_syntax
proc ::rss-synd::xml_get_position {xml_data ptr {end -1}} {
        if {$end >= 0 && $ptr > $end} {
                return ""
        }

        set tag_start [list -1 -1]
        array set tmp {}

        regexp -indices -start $ptr {<(.+?)>} $xml_data -> tmp(tag)
        regexp -indices -start $ptr {<(!--.*?--)>} $xml_data -> tmp(comment)
        regexp -indices -start $ptr {<(!DOCTYPE.+?)>} $xml_data -> tmp(doctype)
        regexp -indices -start $ptr {<(!\[CDATA\[.+?\]\])>} $xml_data -> tmp(cdata)

        foreach name [lsort [array names tmp]] {
                set tmp_s [split $tmp($name)]
                if {$end >= 0 && [lindex $tmp_s 0] > $end} {
                        continue
                }

                if {( ([lindex $tmp_s 0] < [lindex $tag_start 0]) &&
                      ([lindex $tmp_s 0] > -1) ) ||
                    ([lindex $tag_start 0] == -1)} {
                        set tag_start $tmp($name)
                }
        }

        if {([lindex $tag_start 0] == -1) ||
            ([lindex $tag_start 1] == -1)}  {
                return ""
        }

        if {$end >= 0 && [lindex $tag_start 1] > $end} {
                return ""
        }

        return $tag_start
}

# recursivly flatten all data without tags or attributes
proc ::rss-synd::xml_list_flatten {xml_list {level 0}} {
	set xml_string ""

	foreach e_list $xml_list {
		if {[catch {array set e_array $e_list}] != 0} {
			return $xml_list
		}

		if {[info exists e_array(children)]} {
			append xml_string [[namespace current]::xml_list_flatten $e_array(children) [expr { $level + 1 }]]
		} elseif {[info exists e_array(data)]} {
			append xml_string $e_array(data)
		}

		unset e_array
	}

	return $xml_string
}

# returns information on a data structure when given a path.
#  paths can be specified using: [struct number] [struct name] <...>
proc ::rss-synd::xml_get_info {xml_list path {element "data"}} {
	set i 0

	foreach {t_data} $xml_list {
		array set t_array $t_data

		# if the name doesnt exist set it so we can still reference the data
		#  using the 'stuct name' *
		if {![info exists t_array(name)]} {
			set t_array(name) ""
		}

		if {[string match -nocase [lindex $path 1] $t_array(name)]} {

			if {$i == [lindex $path 0]} {
				set result ""

				if {([llength $path] == 2) && \
				    ([info exists t_array($element)])} {
					set result $t_array($element)
				} elseif {[info exists t_array(children)]} {
					# shift the first path reference of the front of the path and recurse
					set result [[namespace current]::xml_get_info $t_array(children) [lreplace $path 0 1] $element]
				}

				return $result
			}

			incr i
		}

		unset t_array
	}

	if {[lindex $path 0] == -1} {
		return $i
	}
}

# converts 'args' into a list in the same order
proc ::rss-synd::xml_join_tags {args} {
	set list [list]

	foreach tag $args {
		foreach item $tag {
			if {[string length $item] > 0} {
				lappend list $item
			}
		}
	}

	return $list
}

#
# Output Feed Functions
##

proc ::rss-synd::feed_output {data {odata ""}} {
	upvar 1 feed feed
	set msgs [list]

	set path [[namespace current]::xml_join_tags $feed(tag-feed) $feed(tag-list) -1 $feed(tag-name)]
	set count [[namespace current]::xml_get_info $data $path]

	for {set i 0} {($i < $count) && ($i < $feed(announce-output))} {incr i} {
		set tmpp [[namespace current]::xml_join_tags $feed(tag-feed) $feed(tag-list) $i $feed(tag-name)]
		set tmpd [[namespace current]::xml_get_info $data $tmpp "children"]

		if {[[namespace current]::feed_compare $odata $tmpd]} {
			break
		}

		set tmp_msg [[namespace current]::cookie_parse $data $i]
		if {(![info exists feed(output-order)]) || \
		    ($feed(output-order) == 0)} {
			set msgs [linsert $msgs 0 $tmp_msg]
		} else {
			lappend msgs $tmp_msg
		}
	}

	set nick [expr {[info exists feed(nick)] ? $feed(nick) : ""}]

	[namespace current]::feed_msg $feed(type) $msgs $feed(channels) $nick
}

proc ::rss-synd::feed_msg {type msgs targets {nick ""}} {
	# check if our target is a nick
	if {(($nick != "") && \
	     ($targets == "")) || \
	    ([regexp -- {[23]} $type])} {
		set targets $nick
	}

	foreach msg $msgs {
		foreach chan $targets {
			if {([catch {botonchan $chan}] == 0) || \
			    ([regexp -- {^[#&]} $chan] == 0)} {
				foreach line [split $msg "\n"] {
					if {($type == 1) || ($type == 3)} {
						putserv "NOTICE $chan :$line"
					} else {
						putserv "PRIVMSG $chan :$line"
					}
				}
			}
		}
	}
}

proc ::rss-synd::feed_compare {odata data} {
	if {$odata == ""} {
		return 0
	}

	upvar 1 feed feed
	array set ofeed [list]
	[namespace current]::feed_info $odata "ofeed"

        if {[array size ofeed] == 0} {
                ::rss-synd::log_message error "\002RSS Error\002: Invalid feed format ($feed(database))!"
                return 0
        }

	if {[string equal -nocase [lindex $feed(tag-feed) 1] "feed"]} {
		set cmp_items [list {0 "id"} "children" "" 3 {0 "link"} "attrib" "href" 2 {0 "title"} "children" "" 1]
	} else {
		set cmp_items [list {0 "guid"} "children" "" 3 {0 "link"} "children" "" 2 {0 "title"} "children" "" 1]
	}

	set path [[namespace current]::xml_join_tags $ofeed(tag-feed) $ofeed(tag-list) -1 $ofeed(tag-name)]
	set count [[namespace current]::xml_get_info $odata $path]

	for {set i 0} {$i < $count} {incr i} {
		# extract the current article from the database
		set tmpp [[namespace current]::xml_join_tags $ofeed(tag-feed) $ofeed(tag-list) $i $ofeed(tag-name)]
		set tmpd [[namespace current]::xml_get_info $odata $tmpp "children"]

		set w 0; # weight value
		set m 0; # item tag matches
		foreach {cmp_path cmp_element cmp_attrib cmp_weight} $cmp_items {
			# try and extract the tag info from the current article
			set oresult [[namespace current]::xml_get_info $tmpd $cmp_path $cmp_element]
			if {$cmp_element == "attrib"} {
				array set tmp $oresult
				catch {set oresult $tmp($cmp_attrib)}
				unset tmp
			}

			# if the tag doesnt exist in the article ignore it
			if {$oresult == ""} { continue }

			incr m

			# extract the tag info from the current article
			set result [[namespace current]::xml_get_info $data $cmp_path $cmp_element]
			if {$cmp_element == "attrib"} {
				array set tmp $result
				catch {set result $tmp($cmp_attrib)}
				unset tmp
			}

			if {[string equal -nocase $oresult $result]} {
				set w [expr { $w + $cmp_weight }]
			}
		}

		# value of 100 or more means its a match
		if {($m > 0) && \
		    ([expr { round(double($w) / double($m) * 100) }] >= 100)} {
			return 1
		}
	}

	return 0
}

#
# Cookie Parsing Functions
##

proc ::rss-synd::cookie_extract {data current token eval} {
        upvar 1 feed feed

        set tmpc [split $token "!"]
        set cookie [list]
        set index 0

        foreach piece $tmpc {
                set tmpp [regexp -nocase -inline -all -- {^(.*?)\((.*?)\)|(.*?)$} $piece]

                if {[lindex $tmpp 3] == ""} {
                        lappend cookie [lindex $tmpp 2] [lindex $tmpp 1]
                } else {
                        lappend cookie 0 [lindex $tmpp 3]
                }
        }

        if {[llength $cookie] < 2} {
                return ""
        }

        if {[string equal -nocase $feed(tag-name) [lindex $cookie 1]]} {
                set cookie [[namespace current]::xml_join_tags $feed(tag-list) [lreplace $cookie $index $index $current]]
        }

        set cookie [[namespace current]::xml_join_tags $feed(tag-feed) $cookie]

        if {[set tmp [[namespace current]::cookie_replace $cookie $data]] == ""} {
                return ""
        }

        set tmp [[namespace current]::xml_list_flatten $tmp]
        set value [string map {"&" "\\\\x26"} [[namespace current]::html_decode $eval $tmp]]

        return [string trim $value]
}

proc ::rss-synd::entry_publication_suffix {data current eval} {
        set candidates {
                "item!pubDate"
                "entry!published"
                "entry!updated"
                "item!dc:date"
        }

        foreach token $candidates {
                set value [[namespace current]::cookie_extract $data $current $token $eval]
                if {$value ne ""} {
                        return [string cat " \u2013 " $value]
                }
        }

        return ""
}

proc ::rss-synd::cookie_parse {data current} {
        upvar 1 feed feed
        set output $feed(output)

        set eval 0
        if {([info exists feed(evaluate-tcl)]) && ($feed(evaluate-tcl) == 1)} { set eval 1 }

        if {[string match *@@published@@* $output]} {
                set published [[namespace current]::entry_publication_suffix $data $current $eval]
                set output [string map {"@@published@@" $published} $output]
        }
        set variable_index 0

	set matches [regexp -inline -nocase -all -- {@@(.*?)@@} $output]
	foreach {match tmpc} $matches {
		set tmpc [split $tmpc "!"]
		set index 0
		set cookie [list]
		incr variable_index
		foreach piece $tmpc {
			set tmpp [regexp -nocase -inline -all -- {^(.*?)\((.*?)\)|(.*?)$} $piece]

			if {[lindex $tmpp 3] == ""} {
				lappend cookie [lindex $tmpp 2] [lindex $tmpp 1]
			} else {
				lappend cookie 0 [lindex $tmpp 3]
			}
		}

		# replace tag-item's index with the current article
		if {[string equal -nocase $feed(tag-name) [lindex $cookie 1]]} {
			set cookie [[namespace current]::xml_join_tags $feed(tag-list) [lreplace $cookie $index $index $current]]
		}

		set cookie [[namespace current]::xml_join_tags $feed(tag-feed) $cookie]

		if {[set tmp [[namespace current]::cookie_replace $cookie $data]] != ""} {
			set tmp [[namespace current]::xml_list_flatten $tmp]

			regsub -all -- {([\"\$\[\]\{\}\(\)\\])} $match {\\\1} match
			set feed_data "[string map { "&" "\\\x26" } [[namespace current]::html_decode $eval $tmp]]"
			if {$eval == 1} {
				# We are going to eval this string so we can't insert untrusted
				# text. Instead create variables and insert references to those
				# variables that will be expanded in the subst call below.
				set cookie_val($variable_index) $feed_data
				regsub -- $match $output "\$cookie_val($variable_index)" output
			} else {
				regsub -- $match $output $feed_data output
			}
		}
	}

	# remove empty cookies
	if {(![info exists feed(remove-empty)]) || ($feed(remove-empty) == 1)} {
		regsub -nocase -all -- "@@.*?@@" $output "" output
	}

	# evaluate tcl code
        if {$eval == 1} {
                if {[catch {set output [subst $output]} error] != 0} {
                        ::rss-synd::log_message error "\002RSS Eval Error\002: $error"
                }
        }

	return $output
}

proc ::rss-synd::cookie_replace {cookie data} {
	set element "children"

	set tags [list]
	foreach {num section} $cookie {
		if {[string equal "=" [string range $section 0 0]]} {
			set attrib [string range $section 1 end]
			set element "attrib"
			break
		} else {
			lappend tags $num $section
		}
	}

	set return [[namespace current]::xml_get_info $data $tags $element]

	if {[string equal -nocase "attrib" $element]} {
		array set tmp $return

		if {[catch {set return $tmp($attrib)}] != 0} {
			return
		}
	}

	return $return
}

#
# Misc Functions
##

proc ::rss-synd::html_decode {eval data {loop 0}} {
	if {![string match *&* $data]} {return $data}
	array set chars {
			 nbsp	\x20 amp	\x26 quot	\x22 lt		\x3C
			 gt		\x3E iexcl	\xA1 cent	\xA2 pound	\xA3
			 curren	\xA4 yen	\xA5 brvbar	\xA6 brkbar	\xA6
			 sect	\xA7 uml	\xA8 die	\xA8 copy	\xA9
			 ordf	\xAA laquo	\xAB not	\xAC shy	\xAD
			 reg	\xAE hibar	\xAF macr	\xAF deg	\xB0
			 plusmn	\xB1 sup2	\xB2 sup3	\xB3 acute	\xB4
			 micro	\xB5 para	\xB6 middot	\xB7 cedil	\xB8
			 sup1	\xB9 ordm	\xBA raquo	\xBB frac14	\xBC
			 frac12	\xBD frac34	\xBE iquest	\xBF Agrave	\xC0
			 Aacute	\xC1 Acirc	\xC2 Atilde	\xC3 Auml	\xC4
			 Aring	\xC5 AElig	\xC6 Ccedil	\xC7 Egrave	\xC8
			 Eacute	\xC9 Ecirc	\xCA Euml	\xCB Igrave	\xCC
			 Iacute	\xCD Icirc	\xCE Iuml	\xCF ETH	\xD0
			 Dstrok	\xD0 Ntilde	\xD1 Ograve	\xD2 Oacute	\xD3
			 Ocirc	\xD4 Otilde	\xD5 Ouml	\xD6 times	\xD7
			 Oslash	\xD8 Ugrave	\xD9 Uacute	\xDA Ucirc	\xDB
			 Uuml	\xDC Yacute	\xDD THORN	\xDE szlig	\xDF
			 agrave	\xE0 aacute	\xE1 acirc	\xE2 atilde	\xE3
			 auml	\xE4 aring	\xE5 aelig	\xE6 ccedil	\xE7
			 egrave	\xE8 eacute	\xE9 ecirc	\xEA euml	\xEB
			 igrave	\xEC iacute	\xED icirc	\xEE iuml	\xEF
			 eth	\xF0 ntilde	\xF1 ograve	\xF2 oacute	\xF3
			 ocirc	\xF4 otilde	\xF5 ouml	\xF6 divide	\xF7
			 oslash	\xF8 ugrave	\xF9 uacute	\xFA ucirc	\xFB
			 uuml	\xFC yacute	\xFD thorn	\xFE yuml	\xFF
			 ensp	\x20 emsp	\x20 thinsp	\x20 zwnj	\x20
			 zwj	\x20 lrm	\x20 rlm	\x20 euro	\x80
			 sbquo	\x82 bdquo	\x84 hellip	\x85 dagger	\x86
			 Dagger	\x87 circ	\x88 permil	\x89 Scaron	\x8A
			 lsaquo	\x8B OElig	\x8C oelig	\x8D lsquo	\x91
			 rsquo	\x92 ldquo	\x93 rdquo	\x94 ndash	\x96
			 mdash	\x97 tilde	\x98 scaron	\x9A rsaquo	\x9B
			 Yuml	\x9F apos	\x27
			}

	regsub -all -- {<(.[^>]*)>} $data " " data

	if {$eval != 1} {
		regsub -all -- {([\$\[\]\{\}\(\)\\])} $data {\\\1} data
	} else {
		regsub -all -- {([\$\[\]\{\}\(\)\\])} $data {\\\\\\\1} data
	}

	regsub -all -- {&#(\d+);} $data {[subst -nocomm -novar [format \\\u%04x [scan \1 %d]]]} data
	regsub -all -- {&#x(\w+);} $data {[format %c [scan \1 %x]]} data
	regsub -all -- {&([0-9a-zA-Z#]*);} $data {[if {[catch {set tmp $chars(\1)} char] == 0} { set tmp }]} data
	regsub -all -- {&([0-9a-zA-Z#]*);} $data {[if {[catch {set tmp [string tolower $chars(\1)]} char] == 0} { set tmp }]} data

	regsub -nocase -all -- "\\s{2,}" $data " " data

	set data [subst $data]
	if {[incr loop] == 1} {
		set data [[namespace current]::html_decode 0 $data $loop]
	}

	return $data
}

proc ::rss-synd::is_utf8_patched {} { catch {queuesize a} err1; catch {queuesize \u0754} err2; expr {[string bytelength $err2]!=[string bytelength $err1]} }

proc ::rss-synd::check_channel {chanlist chan} {
	foreach match [split $chanlist] {
		if {[string equal -nocase $match $chan]} {
			return 1
		}
	}

	return 0
}

proc ::rss-synd::urldecode {str} {
	regsub -all -- {([\"\$\[\]\{\}\(\)\\])} $str {\\\1} str

	regsub -all -- {%([aAbBcCdDeEfF0-9][aAbBcCdDeEfF0-9]);?} $str {[format %c [scan \1 %x]]} str

	return [subst $str]
}

::rss-synd::init
