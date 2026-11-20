## Configuration
### Configuration formats
`rss-set.tcl` contains the format switch and a Tcl example configuration. The key `settings(config-format)` decides which format is loaded:
```tcl
namespace eval ::rss-synd {
    # "tcl" uses the example configuration in rss-set.tcl (default).
    # "toml" reads rss-set.toml and requires the "tomltcl" package.
    set settings(config-format) tcl
    # Optional overrides for custom paths:
    # set settings(config-toml-file) "config/rss-set.toml"
    # set settings(config-tcl-file)  "config/rss-synd-legacy.tcl"
}
```
- **TOML**: `rss-set.toml` contains a `[defaults]` table and `[feeds.<name>]` sections. Example:
  ```toml
  [defaults]
  announce-output = 3
  trigger-type = "0:2"
  [feeds.news]
  url = "https://example.tld/feed.xml"
  channels = "#news #alerts"
  ```
- **Tcl**: Set `config-format` to `tcl` and optionally specify `config-tcl-file`. Without a custom path the example configuration in `rss-set.tcl` is used.
Use `tclsh tools/config-convert.tcl --from tcl --to toml --input rss-set.tcl --output converted.toml`
to convert a configuration. Swap the formats and use a Tcl output filename for the reverse direction.
Both directions require `tomltcl` on Tcl's package path. Only convert trusted Tcl files because the converter executes their contents. Pass the file containing the feed definitions if your settings are split across files.
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
| `user-agent` | HTTP User-Agent header; accepts a static string or a Tcl list of candidates. Use `user-agent-rotate = list` to rotate a list. | `rss-synd/1.0` in the shipped example | `rss-synd/1.0` |
| `announce-type` | Mode for automatic announcements (`0` = channel message, `1` = channel notice). | `0` | `1` |
| `announce-output` | Number of items per announcement (`0` disables announcements). | `3` | `5` |
| `trigger-type` | Output mode for triggers `<channel>:<privmsg>` (`0/1` for channel, `2/3` for user). | `0:2` | `1:3` |
| `trigger-output` | Number of items per trigger (`0` disables triggers). | `3` | `1` |
| `update-interval` | Polling interval in minutes. | `30` | `60` |
> **Note:** The default template uses the combined `@@published@@` placeholder. It checks `pubDate`, `published`, `updated`, then `dc:date` and only adds an en dash plus date when one of them is present.
### Optional settings
| Option | Description | Default | Example |
| --- | --- | --- | --- |
| `https-allow-legacy` | Allows TLS 1.0/1.1 as a fallback (insecure). | `0` | `1` |
| `log-mode` | Logging strategy for Eggdrop’s console output. Use `immediate` for direct `putlog` calls or `buffered` to collect messages and emit summaries. | `immediate` | `buffered` |
| `log-interval` | Interval in minutes before buffered log summaries are flushed. Ignored when `log-mode` is `immediate`. | `5` | `10` |
| `debug-mode` | Enables diagnostics for TLS (`tls`), HTTP requests (`http`), and redirects (`redirect`). Accepts comma- or space-separated values or `all`. | *(empty)* | `tls,redirect` |
| `user-agent-rotate` | Rotation strategy for the User-Agent list: use `list` for round-robin or pass a command name that returns the next agent. The command receives the feed name and current settings and may return a string or a dict containing `user-agent` plus extra state. | `list` | `list` / `::my::ua::next` |
| `trigger` | Public trigger text; `@@feedid@@` is replaced with the feed ID. | `!rss @@feedid@@` | `!news @@feedid@@` |
| `evaluate-tcl` | Runs outputs through Tcl before sending them. | `0` | `1` |
| `enable-gzip` | Enables gzip decompression for feeds. | `0` | `1` |
| `remove-empty` | Removes empty cookies from the output. | `1` | `0` |
| `output-order` | Order of items (`0` = oldest→newest, `1` = newest→oldest). | `0` | `1` |
| `charset` | Target character set for messages. | System default | `utf-8` |
| `feedencoding` | Forces a character set when reading the feed. | – | `cp1251` |
### User-Agent rotation
The script contains a built-in pool of browser identifiers. The shipped example configuration uses `rss-synd/1.0`; set `user-agent` to a Tcl list and `user-agent-rotate` to `list` to rotate through your own candidates. A single string sends a fixed User-Agent.
### Cookies
| Cookie | Meaning | Example |
| --- | --- | --- |
| `@@title@@` | Title of the feed or the current item (depending on context). | `New release available` |
| `@@entry!link@@` | Link of the current item. | `https://example.tld/post` |
| `@@entry!link!=href@@` | Value of the `href` attribute of a link tag. | `https://example.tld/post` |
| `@@entry!author!name@@` | Name of the author in the item. | `Jane Doe` |
| `@@published@@` | Automatically determined publication timestamp (checks `pubDate`, `published`, `updated`, then `dc:date` and only adds ` – date` when a value exists). | ` – Tue, 01 Oct 2024 12:00:00 +0200` |
## Example files and conversion
The repository includes ready-to-edit examples in [`rss-set.tcl`](../rss-set.tcl) and [`rss-set.toml`](../rss-set.toml). Both contain placeholder feed URLs, channel names, and database paths; replace them with your own values.
Convert trusted configuration files with `tools/config-convert.tcl`. Both directions require `tomltcl`; Tcl configuration files are executed during conversion, so only convert files you trust.
### Logging & keeping DCC quiet
Eggdrop writes script output to the party line (DCC chat). To reduce noise you can enable buffered logging:
1. Set `log-mode` to `buffered` in the defaults.
2. Adjust `log-interval` to define how many minutes the script should wait before it flushes a summary (counts per level plus first/last message).
While buffered mode is active, individual log entries are grouped and only a compact digest is sent to DCC at the chosen interval. Switching back to `immediate` restores the previous behaviour.
## Compatibility & versions
- Requires Eggdrop with Tcl 8.6 and the standard `http` and `zlib` packages; optional features rely on `base64`, `tls`, and `tomltcl`.
- HTTPS certificates are validated by default. The script enables TLS 1.2/1.3 and registers its own TLS sockets.
- `https-allow-legacy` permits older TLS protocols as a fallback and is insecure; enable it only when required by the server.

### Feed cache

Each `database` path holds a text file containing a Tcl list representation of the parsed and trimmed feed, used to compare entries between polls. It is not SQLite. Keep each feed's cache path separate and writable. Existing cache files remain compatible; protect them as they can contain feed content and URLs.
