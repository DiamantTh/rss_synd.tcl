#
# Start of Settings
#

#
# See the README file for more information
#

namespace eval ::rss-synd {
	variable rss
	variable default



set rss(msbulletins) {
		"url"			"http://technet.microsoft.com/en-us/security/rss/bulletin"
		"channels"		"#channel"
		"database"		"/path to dir/msbulletins.db"
		"output"		"[\00312\002MS Security bulletins\002\003] \00310\002@@item!title@@\002\003 - @@item!link@@"
		"trigger"		"!msbulletins"
		"announce-output"	5
		"trigger-output"	5
		"update-interval"	10
		"output-order"	0
	}
	
	#set rss(test1) {
	#	"url"			"http://www.pheedo.com/f/newscientist_space/atom10"
	#	"channels"		"#test"
	#	"database"		"./scripts/feeds/test1.db"
	#	"trigger"		"!@@feedid@@"
	#}

	#set rss(test2) {
	#	"url"			"http://milw0rm.com/rss.php"
	#	"channels"		"#test"
	#	"database"		"./scripts/feeds/test2.db"
	#	"trigger"		"!@@feedid@@"
	#}

	#set rss(test3) {
	#	"url"			"http://www.kvirc.net/rss.php"
	#	"channels"		"#test"
	#	"database"		"./scripts/feeds/test3.db"
	#	"output"		"\[\002@@channel!title@@\002\] @@item!title@@ - @@item!guid@@"
	#	"trigger"		"!@@feedid@@"
	#}

	#set rss(test4) {
	#	"url"			"http://www.imaginascience.com/xml/rss.xml"
	#	"channels"		"#test"
	#	"database"		"./scripts/feeds/test4.db"
	#	"trigger"		"!@@feedid@@"
	#}

	# Doesn't work with "charset" "utf-8" because TCL converts characters
	#  with umlauts in to multibyte characters (eg: � = ü). Works fine
	#  without.
	#set rss(test5) {
	#	"url"			"http://www.heise.de/newsticker/heise-atom.xml"
	#	"channels"		"#test"
	#	"database"		"./scripts/feeds/test5.db"
	#	"trigger"		"!@@feedid@@"
	#}

	#set rss(test6) {
	#	"url"			"http://news.google.ru/?output=rss"
	#	"channels"		"#test"
	#	"charset"		"utf-8"
	#	"database"		"./scripts/feeds/test6.db"
	#	"trigger"		"!@@feedid@@"
	#}

	#set rss(test7) {
	#	"url"			"http://news.google.cn/?output=rss"
	#	"channels"		"#test"
	#	"charset"		"utf-8"
	#	"database"		"./scripts/feeds/test7.db"
	#	"trigger"		"!@@feedid@@"
	#}

	#set rss(test8) {
	#	"url"			"http://news.google.it/?output=rss"
	#	"channels"		"#test"
	#	"charset"		"utf-8"
	#	"database"		"./scripts/feeds/test8.db"
	#	"trigger"		"!@@feedid@@"
	#}

	# The default settings, If any setting isn't set for an individual feed
	#   it'll use the defaults listed here.
	#
	# WARNING: You can change the options here, but DO NOT REMOVE THEM, doing
	#   so will create errors.
	set default {
		"announce-output"	3
		"trigger-output"	3
		"remove-empty"		1
		"trigger-type"		0:2
		"announce-type"		0
		"max-depth"			5
		"evaluate-tcl"		0
		"update-interval"	30
		"output-order"		0
                "log-mode"              "immediate"
                "log-interval"         5
		"timeout"			60000
		"channels"			"#channel"
		"trigger"			"!rss @@feedid@@"
		"output"			"\[\002@@channel!title@@@@title@@\002\] @@item!title@@@@entry!title@@ - @@item!link@@@@entry!link!=href@@"
		"user-agent"			{
				"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36"
				"Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36"
				"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
				"Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
				"Mozilla/5.0 (iPad; CPU OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
				"Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro Build/AP2A.240605.024) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.6533.72 Mobile Safari/537.36"
				"Mozilla/5.0 (Linux; Android 14; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Mobile Safari/537.36"
			}
                "user-agent-rotate"             "list"
		"https-allow-legacy"		0
	}
}

#
# End of Settings
#
################################################################################
