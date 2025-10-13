#
# Konfigurationsschalter für rss_synd.tcl
#
# Variante "toml":
#   - Standardmodus, liest Einstellungen aus "rss-set.toml".
#   - Erfordert das Tcllib-Paket "toml".
# Variante "tcl":
#   - Lädt klassische Tcl-Listen aus der in "config-tcl-file" angegebenen Datei.
#   - Ohne Angabe wird der eingebaute Fallback aus rss_synd.tcl genutzt.
#

namespace eval ::rss-synd {
	variable settings
	variable default
	variable rss

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
		set settings(debug-mode) ""
	}

	set ctrl2 [format %c 2]
	set ctrl3 [format %c 3]
	set defaultOutput [string cat {[} $ctrl2 {@@channel!title@@@@title@@} $ctrl2 {] @@item!title@@@@entry!title@@ - @@item!link@@@@entry!link!=href@@}]
	set msBulletinsOutput [string cat {[} $ctrl3 {12} $ctrl2 {MS Security bulletins} $ctrl2 $ctrl3 {] } $ctrl3 {10} $ctrl2 {@@item!title@@} $ctrl2 $ctrl3 { - @@item!link@@}]

	set default [list \
		"announce-output"	3 \
		"trigger-output"	3 \
		"remove-empty"		1 \
		"trigger-type"		0:2 \
		"announce-type"		0 \
		"max-depth"		5 \
		"evaluate-tcl"		0 \
		"update-interval"	30 \
		"output-order"		0 \
		"log-mode"		"immediate" \
		"log-interval"		5 \
		"timeout"		60000 \
		"channels"		"#channel" \
		"trigger"		"!rss @@feedid@@" \
		"output"		$defaultOutput \
		"user-agent" [list \
			"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36" \
			"Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36" \
			"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36" \
			"Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1" \
			"Mozilla/5.0 (iPad; CPU OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1" \
			"Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro Build/AP2A.240605.024) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.6533.72 Mobile Safari/537.36" \
			"Mozilla/5.0 (Linux; Android 14; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Mobile Safari/537.36" \
		] \
		"user-agent-rotate"	"list" \
		"https-allow-legacy"	0 \
	]

	if {[array exists rss]} {
		array unset rss
	}
	array set rss {}
	set rss(msbulletins) [list \
		"url"			"http://technet.microsoft.com/en-us/security/rss/bulletin" \
		"channels"		"#channel" \
		"database"		"/path to dir/msbulletins.db" \
		"output"		$msBulletinsOutput \
		"trigger"		"!msbulletins" \
		"announce-output"	5 \
		"trigger-output"	5 \
		"update-interval"	10 \
		"output-order"		0 \
	]

	unset ctrl2
	unset ctrl3
	unset defaultOutput
	unset msBulletinsOutput
}
