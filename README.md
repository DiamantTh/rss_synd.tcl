# RSS Synd Script

> **German version:** See [README.de.md](README.de.md).

## Introduction
The `rss_synd.tcl` script extends Eggdrop bots with the ability to automatically read RSS and Atom feeds, detect new entries, and announce them in IRC channels. It supports secure connections, customizable output, and flexible trigger mechanisms.

### Key features
- Regular polling and announcing of multiple RSS/Atom feeds.
- Support for HTTP authentication, HTTPS, and gzip-compressed feeds.
- Customizable triggers, output formats, and announcement options per feed.
- Optional post-processing of outputs via Tcl expressions.

## Installation
1. Copy `rss_synd.tcl` and `rss-synd-settings.tcl` into your Eggdrop bot's script directory.
2. Add the line `source scripts/rss-synd.tcl` to your `eggdrop.conf` (adjust the path as needed).

### Package installation (optional features)
The following optional features require additional Tcl extensions:

| Feature | Required Tcl extensions |
|---------|-------------------------|
| HTTP authentication | `base64` from `tcllib` |
| HTTPS support | `tls` |
| Gzip decompression | `Trf` |

Install the required extensions via your platform's package manager, prebuilt Tcl packages, or community repositories.

## Dependencies and notes
The script runs without additional packages, but certain features are only available with the extensions listed above.

- **HTTPS note:** Certificates are validated by default and only TLS 1.2/1.3 are enabled. If your environment only offers older protocols, set the `https-allow-legacy` option to `1` (insecure, for emergencies only).

## Configuration
The following options can be defined globally in the default configuration or per feed. Feed-specific values override global settings.

### Required fields
| Option | Description | Default | Example |
| --- | --- | --- | --- |
| `url` | Address of the RSS/Atom feed. | – | `https://example.tld/feed.xml` |
| `channels` | List of channels for announcements and triggers (space-separated). | `#channel` | `#news #alerts` |
| `database` | Path to the database file. | – | `./scripts/news.db` |
| `output` | Message format with cookies for announcements. | `[\002@@channel!title@@@@title@@\002] @@item!title@@@@entry!title@@ - @@item!link@@@@entry!link!=href@@` | `[\002@@channel!title@@\002] @@item!title@@ – @@item!link@@` |
| `max-depth` | Maximum number of allowed HTTP redirects. | `5` | `3` |
| `timeout` | Connection timeout in milliseconds. | `60000` | `45000` |
| `user-agent` | HTTP User-Agent header. | `Mozilla/5.0 (Windows; U; Windows NT 6.1; en-GB; rv:1.9.2.2) Gecko/20100316 Firefox/3.6.2` | `rss-synd/git-198a7a4 (+https://example.tld)` |
| `announce-type` | Mode for automatic announcements (`0` = channel message, `1` = channel notice). | `0` | `1` |
| `announce-output` | Number of items per announcement (`0` disables announcements). | `3` | `5` |
| `trigger-type` | Output mode for triggers `<channel>:<privmsg>` (`0/1` for channel, `2/3` for user). | `0:2` | `1:3` |
| `trigger-output` | Number of items per trigger (`0` disables triggers). | `3` | `1` |
| `update-interval` | Polling interval in minutes. | `30` | `60` |

### Optional settings
| Option | Description | Default | Example |
| --- | --- | --- | --- |
| `https-allow-legacy` | Allows TLS 1.0/1.1 as a fallback (insecure). | `0` | `1` |
| `trigger` | Public trigger text; `@@feedid@@` is replaced with the feed ID. | `!rss @@feedid@@` | `!news @@feedid@@` |
| `evaluate-tcl` | Runs outputs through Tcl before sending them. | `0` | `1` |
| `enable-gzip` | Enables gzip decompression for feeds. | `0` | `1` |
| `remove-empty` | Removes empty cookies from the output. | `1` | `0` |
| `output-order` | Order of items (`0` = oldest→newest, `1` = newest→oldest). | `0` | `1` |
| `charset` | Target character set for messages. | System default | `utf-8` |
| `feedencoding` | Forces a character set when reading the feed. | – | `cp1251` |

### Cookies
| Cookie | Meaning | Example |
| --- | --- | --- |
| `@@title@@` | Title of the feed or the current item (depending on context). | `New release available` |
| `@@entry!link@@` | Link of the current item. | `https://example.tld/post` |
| `@@entry!link!=href@@` | Value of the `href` attribute of a link tag. | `https://example.tld/post` |
| `@@entry!author!name@@` | Name of the author in the item. | `Jane Doe` |

## Example configuration
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

## Compatibility & versions
- Script version git-198a7a4 dated 03 Oct 2025. You can find the version information in the header of `rss_synd.tcl`.
- Requires an Eggdrop with Tcl support and the standard `http` package; optional features rely on `base64`, `tls`, and `Trf` (`package require …` in `rss_synd.tcl`).
- For HTTPS connections the script enables TLS 1.2/1.3 by default and registers its own TLS sockets; you can enable older protocols via `https-allow-legacy` if needed.
