# RSS Synd Script

> **German version:** See [README.de.md](README.de.md).

[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](LICENSE)

The inherited code is licensed under BSD-3-Clause. Originally written by Andrew Scott, with HM2K as an upstream contributor; adapted by Pho3niX (MICE07) and maintained here by DiamantTh.

RSS Synd is an Eggdrop Tcl script that polls RSS and Atom feeds and announces new entries in IRC channels.

## Features

- Polls multiple feeds and announces new entries.
- Supports HTTPS, HTTP authentication, and optional gzip decompression.
- Provides per-feed triggers, output formats, and announcement settings.
- Supports Tcl or TOML configuration.

## Quick start

1. Copy `rss-synd.tcl` and one example configuration file, `rss-set.tcl` or `rss-set.toml`, to your Eggdrop scripts directory.
2. Edit the example configuration with your feed URL, channel, and database path.
3. Source `rss-synd.tcl` from `eggdrop.conf`, for example: `source scripts/rss-synd.tcl`.

The supplied `rss-set.tcl` selects Tcl configuration. To use TOML, change `settings(config-format)` to `toml` and install `tomltcl`.

## Optional packages

| Feature | Tcl package |
|---------|-------------|
| HTTPS | `tls` |
| HTTP authentication | `base64` from Tcllib |
| Gzip decompression | `Trf` |
| TOML configuration and conversion | [`tomltcl`](https://github.com/avohra25/tomltcl) |

See the [configuration guide](docs/configuration.md) for options, output cookies, logging, and conversion details. The [Tcl example](rss-set.tcl) and [TOML example](rss-set.toml) use placeholder feed details.

## License and project history

The inherited code is distributed under the [BSD 3-Clause License](LICENSE). Andrew Scott wrote the original script, and HM2K is credited as an upstream contributor. Pho3niX (MICE07) adapted the code in 2014; this fork is maintained by DiamantTh. See the [upstream project](https://github.com/eggtcl/rss-synd) and the [MICE07 parent repository](https://github.com/MICE07/rss_synd.tcl).
