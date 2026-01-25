# Terminal Void (Zola theme)

A small, readable Zola theme with a terminal-ish vibe: ~81ch content width, quiet borders, and a single accent color.

## Install

1. Copy/clone this folder into your Zola site:

   `themes/terminal-void/`

2. Enable it in your site's `config.toml` (top-level!):

```toml
theme = "terminal-void"
```

Zola expects the `theme` key at the top-level of `config.toml` (not under `[extra]`).

## Suggested config (Zola v0.22+)

```toml
base_url = "https://example.com"
title = "My Site"
description = "Notes from the void."
generate_feeds = true

taxonomies = [
  { name = "tags", feed = true },
]

# Zola v0.22+ syntax highlighting (Giallo)
[markdown.highlighting]
style = "class"        # "inline" (default) or "class"
light_theme = "github-light"
dark_theme  = "github-dark"

[extra]
accent = "#6cf9ff"
menu = [
  { name = "Home", url = "/" },
  { name = "Tags", url = "/tags/" },
]
social = [
  { name = "GitHub", url = "https://github.com/yourname", external = true },
]
```

## Content tips

- To paginate a section, set `paginate_by` in that section's `_index.md`.
- To show a table of contents on a page, set this in the page front matter:

```toml
[extra]
toc = true
```

## Customize

Most theme strings & links are pulled from `config.toml`:

- `title`, `description`
- `[extra]` keys: `accent`, `menu`, `social`, etc.

You can override any theme template or static file by creating a file with the same path in your site's `templates/` or `static/` folder.
