# Colours

Two colour schemes are in use, deliberately. Anything that looks like a stray colour override should
be traceable to one of them.

| | Scheme | Where it applies |
|---|---|---|
| **Terminal** | Ghostty's built-in default | Every shell session — bare Ghostty/zellij panes *and* terminal buffers inside nvim. Also Claude Code's default text. |
| **Editor** | onedark `dark`, one override | Code in nvim. |

## Terminal scheme — Ghostty's default

Ghostty's config sets **no colours at all**, so its compiled-in defaults are the scheme. They are a
hybrid, not a single named theme:

| Part | Value | Source |
|---|---|---|
| background | `#282c34` | One Dark's background (*not* Tomorrow Night's `#1d1f21`) |
| foreground | `#ffffff` | pure white (*not* Tomorrow Night's `#c5c8c6`) |
| ANSI 0–7 | `#1d1f21 #cc6666 #b5bd68 #f0c674 #81a2be #b294bb #8abeb7 #c5c8c6` | **Tomorrow Night**, exactly |
| ANSI 8–15 | `#666666 #d54e53 #b9ca4a #e7c547 #7aa6da #c397d8 #70c0b1 #eaeaea` | **Tomorrow Night Bright**, exactly |

Verified by diffing `ghostty +show-config --default` against the bundled `Tomorrow Night` and
`Tomorrow Night Bright` theme files in `/Applications/Ghostty.app/Contents/Resources/ghostty/themes`.

## Editor scheme — onedark with a lighter foreground

Stock onedark `dark` except for body text:

| | Value | Contrast on `#282c34` |
|---|---|---|
| onedark stock | `#abb2bf` | 6.57:1 |
| **in use** | **`#d4d8df`** | **9.79:1** |
| terminal scheme | `#ffffff` | 14.00:1 |

`#d4d8df` is the perceptual midpoint, interpolated in CIELAB rather than hex so it keeps onedark's
cool grey tint instead of drifting to neutral grey. Others on the same line, if it needs a nudge:
`#c0c5cf` (8.1:1) · `#ccd0d8` (9.1:1) · `#dde0e5` (10.6:1) · `#eaebef` (11.8:1).

**Why a midpoint.** How heavy the foreground feels depends on how much of the screen it occupies.
Lua colours most tokens as keywords or strings, so `fg` barely shows and onedark's stock grey looks
fine; Go leaves identifiers, receivers and field names unstyled, so `fg` dominates and the same grey
reads as washed out next to a Claude pane. Pure white fixes Go and is far too hot for Lua. Tune this
value against a Go buffer, not a Lua one.

**Why the accents stay stock.** onedark's accents are more *colourful* than Ghostty's, though not
higher contrast — WCAG contrast is luminance-only and can't see this:

| | onedark | Ghostty | |
|---|---|---|---|
| blue | `#61afef` C\*=39.6 | `#81a2be` C\*=18.7 | **2.12×** chroma |
| purple | `#c678dd` C\*=61.2 | `#b294bb` C\*=24.3 | **2.52×** chroma |
| red | `#e86671` C\*=54.8 | `#cc6666` C\*=44.6 | 1.23× chroma |
| green | `#98c379` C\*=42.7 | `#b5bd68` C\*=44.6 | 0.96× — indistinguishable |

Accent contrast means are a dead heat (6.00:1 vs 6.11:1), so contrast is the wrong metric for
choosing between them. That chroma difference is the whole reason to run a separate scheme for code.

## Where each is defined

| File | Sets | Notes |
|---|---|---|
| `src/.config/ghostty/config` | *nothing* | Deliberate — the built-in defaults are the terminal scheme. Don't add a `theme`, `background`, `foreground` or `palette` line without updating the nvim mirror. |
| `src/.config/nvim/lua/plugins/colorscheme.lua` | both schemes | The only place hex values live. `terminal_scheme` mirrors Ghostty; `editor_scheme` is onedark plus `fg`. |
| `src/.config/nvim/lua/plugins/snacks.lua` | nothing | `styles.terminal`'s `winhighlight` points terminal panes at the group names only. |
| `src/.config/zellij/config.kdl` | nothing | `theme` stays commented out, so zellij's chrome renders through the terminal's ANSI palette and follows Ghostty for free. |

## Gotchas

- **Claude Code can't be themed.** It emits hardcoded truecolor RGB (`#d77757` terracotta, `#ffc107`
  amber, `#b1b9f9` periwinkle, `#4eba65` green, `#999999` grey) — 46 truecolor sequences and zero
  indexed ANSI in a captured session. Only its default text follows the terminal scheme, which is
  why it looks identical inside nvim and out.
- **nvim terminals need the mirror.** Terminal buffers render ANSI through `g:terminal_color_*`, and
  onedark fills those from its own palette. Without the mirror, `ls` inside nvim is visibly punchier
  than the same command in a bare pane.
- **`g:terminal_color_*` is read at terminal creation.** Changing it doesn't recolour a running
  terminal buffer; reopen it (or restart nvim).
- **A plain `:terminal` misses `TerminalNormal`.** Only snacks-created terminals get the
  `winhighlight`, so a bare `:terminal` shows the editor foreground rather than white.
- **Comments are the one poor value left**, at `#5c6370` / 2.32:1 — below the WCAG 3:1 floor, and
  the lighter body text widens the gap. onedark's own `light_grey` `#848b98` is 4.08:1 if it ever
  becomes annoying. Left alone on purpose.
- **`[delta "tokyonight"]` in `src/.gitconfig` is dead config** — a third scheme's worth of
  hardcoded hex from a tokyonight era. delta is never enabled (no `core.pager`, no
  `interactive.diffFilter`, no `features`, and nothing references the block), so it has no effect.
  Delete it, or wire delta up and restyle it to match, but don't treat it as live.
