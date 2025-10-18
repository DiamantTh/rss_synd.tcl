# RSS Synd Script

> **German version:** See [README.de.md](README.de.md).

## Introduction
The `rss-synd.tcl` script extends Eggdrop bots with the ability to automatically read RSS and Atom feeds, detect new entries, and announce them in IRC channels. It supports secure connections, customizable output, and flexible trigger mechanisms.

## Open tasks
- **Harden feed validation:** Ensure that only valid RSS or Atom feeds are accepted during retrieval and log unexpected formats with clear diagnostics.
- **Improve dedicated logging:** Evaluate a separate logging concept to emit and analyze debug information more precisely.

### Key features
- Regular polling and announcing of multiple RSS/Atom feeds.
- Support for HTTP authentication, HTTPS, and gzip-compressed feeds.
- Customizable triggers, output formats, and announcement options per feed.
- Optional post-processing of outputs via Tcl expressions.

## Installation
1. Copy `rss-synd.tcl` into your Eggdrop bot's script directory.
2. Duplicate `rss-set.example.tcl` as `rss-set.tcl` and adjust the values to your needs. When using the TOML format, also copy `rss-set.example.toml` to `rss-set.toml`.
3. Add the line `source scripts/rss-synd.tcl` to your `eggdrop.conf` (adjust the path as needed).

### Package installation (optional features)
The following optional features require additional Tcl extensions:

| Feature | Required Tcl extensions |
|---------|-------------------------|
| HTTP authentication | `base64` from `tcllib` |
| HTTPS support | `tls` |
| Gzip decompression | `Trf` |
| TOML configuration | `toml` from `tcllib` |

Install the required extensions via your platform's package manager, prebuilt Tcl packages, or community repositories.

## Dependencies and notes
The script runs without additional packages, but certain features are only available with the extensions listed above.

- **HTTPS note:** Certificates are validated by default and only TLS 1.2/1.3 are enabled. If your environment only offers older protocols, set the `https-allow-legacy` option to `1` (insecure, for emergencies only).

## Configuration

### Configuration formats

`rss-set.tcl` (created from `rss-set.example.tcl`) now only holds toggle parameters. The key `settings(config-format)` decides which format is loaded:

```tcl
namespace eval ::rss-synd {
    # "toml" reads rss-set.toml (default name copied from rss-set.example.toml) and requires the Tcllib "toml" package.
    set settings(config-format) toml

    # Optional overrides for custom paths:
    # set settings(config-toml-file) "config/rss-set.toml"
    # set settings(config-tcl-file)  "config/rss-synd-legacy.tcl"
}
```

- **TOML**: `rss-set.toml` (copy of `rss-set.example.toml`) contains a `[defaults]` table and `[feeds.<name>]` sections. Example:

  ```toml
  [defaults]
  announce-output = 3
  trigger-type = "0:2"

  [feeds.news]
  url = "https://example.tld/feed.xml"
  channels = "#news #alerts"
  ```

- **Tcl**: Set `config-format` to `tcl` and optionally specify `config-tcl-file`. Without a custom path the script falls back to the built-in lists (matching the legacy sample configuration). Remember that these fallbacks set `trigger-output` to `0`, keeping triggers silent until you provide your own values.

The following options can be defined globally in the default configuration or per feed. Feed-specific values override global settings.

### Required fields
| Option | Description | Default | Example |
| --- | --- | --- | --- |
| `url` | Address of the RSS/Atom feed. | – | `https://example.tld/feed.xml` |
| `channels` | List of channels for announcements and triggers (space-separated). | `#channel` | `#news #alerts` |
| `database` | Path to the database file. | – | `./scripts/news.db` |
| `output` | Message format with cookies for announcements. | `[\002@@channel!title@@@@title@@\002] @@item!title@@@@entry!title@@@@published@@ - @@item!link@@@@entry!link!=href@@` | `[\002@@channel!title@@\002] @@item!title@@ – @@item!link@@` |
| `max-depth` | Maximum number of allowed HTTP redirects. | `5` | `3` |
| `timeout` | Connection timeout in milliseconds. | `60000` | `45000` |
| `user-agent` | HTTP User-Agent header; accepts a static string or a Tcl list of candidates. Combine with `user-agent-rotate` to enable round-robin or custom rotation logic. | Rotating list of up-to-date desktop and mobile browser identifiers (see below) | `Static: Mozilla/5.0 (compatible; rss-synd/2025.10; +https://example.tld)`<br>`Rotating: {"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36" "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"} + user-agent-rotate list` |
| `announce-type` | Mode for automatic announcements (`0` = channel message, `1` = channel notice). | `0` | `1` |
| `announce-output` | Number of items per announcement (`0` disables announcements). | `3` | `5` |
| `trigger-type` | Output mode for triggers `<channel>:<privmsg>` (`0/1` for channel, `2/3` for user). | `0:2` | `1:3` |
| `trigger-output` | Number of items per trigger (`0` disables triggers). | `3` | `1` |
| `trigger-fetch` | Optional HTTP refresh whenever a trigger runs (`0` = off, `due` = only if interval expired, `force` = always fetch). | `0` | `force` |
| `update-interval` | Polling interval in minutes. | `30` | `60` |

> **Note:** The default template uses the combined `@@published@@` placeholder. It checks `pubDate`, `published`, `updated`, then `dc:date` and only adds an en dash plus date when one of them is present.

### Optional settings
| Option | Description | Default | Example |
| --- | --- | --- | --- |
| `https-allow-legacy` | Allows TLS 1.0/1.1 as a fallback (insecure). | `0` | `1` |
| `debug-mode` | Enables verbose debugging. Pass a Tcl list with any of `http`, `tls`, or `all`. `http` logs outgoing request details, while `tls` activates `::tls::debug` (and logs the applied TLS options if the command is missing). | `{}` | `{http tls}` |
| `log-mode` | Logging strategy for Eggdrop’s console output. Use `immediate` for direct `putlog` calls or `buffered` to collect messages and emit summaries. | `immediate` | `buffered` |
| `log-interval` | Interval in minutes before buffered log summaries are flushed. Ignored when `log-mode` is `immediate`. | `5` | `10` |
| `debug-mode` | Enables verbose diagnostics for TLS (`tls`), HTTP requests (`http`) and redirect handling (`redirect`). Accepts a comma- or space-separated list or `all` to activate everything. | *(empty)* | `tls,http` |
| `user-agent-rotate` | Rotation strategy for the User-Agent list: use `list` for round-robin or pass a command name that returns the next agent. The command receives the feed name and current settings and may return a string or a dict containing `user-agent` plus extra state. | `list` | `list` / `::my::ua::next` |
| `trigger` | Public trigger text; `@@feedid@@` is replaced with the feed ID. | `!rss @@feedid@@` | `!news @@feedid@@` |
| `evaluate-tcl` | Runs outputs through Tcl before sending them. | `0` | `1` |
| `enable-gzip` | Enables gzip decompression for feeds. | `0` | `1` |
| `remove-empty` | Removes empty cookies from the output. | `1` | `0` |
| `output-order` | Order of items (`0` = oldest→newest, `1` = newest→oldest). | `0` | `1` |
| `charset` | Target character set for messages. | System default | `utf-8` |
| `feedencoding` | Forces a character set when reading the feed. | – | `cp1251` |

### Built-in User-Agent rotation

The default configuration ships with a curated pool of current (mid-2025) browser identifiers covering major desktop and mobile platforms:

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

You can replace entries, append your own brands, or switch back to a single static header by supplying a dedicated string and clearing `user-agent-rotate`.

### Cookies
| Cookie | Meaning | Example |
| --- | --- | --- |
| `@@title@@` | Title of the feed or the current item (depending on context). | `New release available` |
| `@@entry!link@@` | Link of the current item. | `https://example.tld/post` |
| `@@entry!link!=href@@` | Value of the `href` attribute of a link tag. | `https://example.tld/post` |
| `@@entry!author!name@@` | Name of the author in the item. | `Jane Doe` |
| `@@published@@` | Automatically determined publication timestamp (checks `pubDate`, `published`, `updated`, then `dc:date` and only adds ` – date` when a value exists). | ` – Tue, 01 Oct 2024 12:00:00 +0200` |

## Example configurations

### TOML (default)
```toml
[defaults]
announce-output = 3
trigger-type = "0:2"
channels = "#channel"
trigger = "!rss @@feedid@@"
output = "[\u0002@@channel!title@@@@title@@\u0002] @@item!title@@@@entry!title@@@@published@@ - @@item!link@@@@entry!link!=href@@"
user-agent = [
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36",
  "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
]
user-agent-rotate = "list"

[feeds.news]
url = "https://example.tld/feed.xml"
channels = "#news #alerts"
database = "./scripts/news.db"
trigger = "!news @@feedid@@"
```

### Tcl (legacy)
```tcl
namespace eval ::rss-synd {
    set rss(news) {
        "url"       "https://example.tld/feed.xml"
        "channels"  "#news #alerts"
        "database"  "./scripts/news.db"
        "output"    "[\002@@channel!title@@@@title@@\002] @@item!title@@@@published@@ - @@item!link@@"
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
        "output"                "[\002@@channel!title@@@@title@@\002] @@item!title@@@@entry!title@@@@published@@ - @@item!link@@@@entry!link!=href@@"
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

### Manual refresh & DCC triggers

If you want on-demand updates there are two options:

1. Set `trigger-fetch` in a feed to `due` (only fetch when the interval has elapsed) or `force` (always issue a new HTTP request) so that public or private triggers refresh the database before printing items.
2. Use the DCC party line command `.rss <feed> [force]` to request a refresh manually. Without the optional `force` argument the script honours the normal interval; supplying `force` bypasses the age check and starts an immediate download.

### Logging & keeping DCC quiet

Eggdrop writes script output to the party line (DCC chat). To reduce noise you can enable buffered logging:

1. Set `log-mode` to `buffered` in the defaults.
2. Adjust `log-interval` to define how many minutes the script should wait before it flushes a summary (counts per level plus first/last message).

While buffered mode is active, individual log entries are grouped and only a compact digest is sent to DCC at the chosen interval. Switching back to `immediate` restores the previous behaviour.

## Compatibility & versions

- Requires an Eggdrop with Tcl support and the standard `http` package; optional features rely on `base64`, `tls`, and `Trf` (`package require …` in `rss-synd.tcl`).
- For HTTPS connections the script enables TLS 1.2/1.3 by default and registers its own TLS sockets; you can enable older protocols via `https-allow-legacy` if needed.
