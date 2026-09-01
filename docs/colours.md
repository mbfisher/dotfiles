# Colours

The terminal stack has coordinated dark and light schemes. Run `terminal-theme`, or press
`Alt+Shift+T` in Zellij, to toggle every layer together. `terminal-theme light`, `dark`, and `status`
are available when an explicit action is clearer.

| | Dark | Light |
|---|---|---|
| **Ghostty and shells** | Ghostty built-in default | Flexoki Light |
| **Zellij chrome** | ANSI palette | Flexoki Light UI theme |
| **nvim code** | onedark `dark`, lighter body text | onedark `light`, Flexoki paper scale |
| **nvim terminal buffers** | Ghostty dark palette mirror | Flexoki Light palette mirror |

`terminal-theme` writes the gitignored `~/.config/ghostty/theme.conf`, reloads Ghostty, switches the
current Zellij session, and sends `SIGUSR1` to running nvim processes. Zellij keeps the ANSI-driven
theme in dark mode, while its explicit Flexoki Light theme avoids retaining stale dark-session ANSI
colours. The selected tab uses muted olive `#879a39`; focused pane titles use green `#66800b`.

## Dark terminal scheme

The dark state sets no Ghostty theme, preserving its compiled-in default:

| Part | Value | Source |
|---|---|---|
| background | `#282c34` | One Dark's background (*not* Tomorrow Night's `#1d1f21`) |
| foreground | `#ffffff` | pure white (*not* Tomorrow Night's `#c5c8c6`) |
| ANSI 0–7 | `#1d1f21 #cc6666 #b5bd68 #f0c674 #81a2be #b294bb #8abeb7 #c5c8c6` | **Tomorrow Night**, exactly |
| ANSI 8–15 | `#666666 #d54e53 #b9ca4a #e7c547 #7aa6da #c397d8 #70c0b1 #eaeaea` | **Tomorrow Night Bright**, exactly |

Verified by diffing `ghostty +show-config --default` against the bundled `Tomorrow Night` and
`Tomorrow Night Bright` theme files in `/Applications/Ghostty.app/Contents/Resources/ghostty/themes`.

## Light terminal scheme

Flexoki Light uses a warm paper background (`#fffcf0`) and near-black foreground (`#100f0f`).
Its ANSI colours remain distinct and readable in direct sunlight without the stark neutral white
and washed-out yellow that made the previous Atom One Light attempt unpleasant.

## Editor schemes

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

The light editor keeps onedark's syntax accents and uses Flexoki's warm background scale:
`#fffcf0`, `#f2f0e5`, `#e6e4d9`, `#cecdc3`. Body text is `#343331`; terminal buffers remain
near-black (`#100f0f`) to match bare Ghostty panes.

## Where each is defined

| File | Sets | Notes |
|---|---|---|
| `src/bin/terminal-theme` | active state | Writes the runtime include, reloads Ghostty, and signals nvim. |
| `src/.config/ghostty/config` | runtime include | Loads the generated `theme.conf`; absence means dark. |
| `src/.config/nvim/lua/plugins/colorscheme.lua` | both scheme mirrors | Switches on `SIGUSR1`; terminal palettes match Ghostty. |
| `src/.config/nvim/lua/plugins/snacks.lua` | nothing | `styles.terminal`'s `winhighlight` points terminal panes at the group names only. |
| `src/.config/zellij/config.kdl` | theme pair and toggle key | Dark uses `ansi`; light uses `flexoki-light`. |
| `src/.config/zellij/themes/flexoki-light.kdl` | light Zellij UI | Defines title, ribbon, frame, and plugin colours. |

## Gotchas

- **Claude Code can't be themed.** It emits hardcoded truecolor RGB (`#d77757` terracotta, `#ffc107`
  amber, `#b1b9f9` periwinkle, `#4eba65` green, `#999999` grey) — 46 truecolor sequences and zero
  indexed ANSI in a captured session. Only its default text follows the terminal scheme, which is
  why it looks identical inside nvim and out.
- **nvim terminals need the mirror.** Terminal buffers render ANSI through `g:terminal_color_*`, and
  onedark fills those from its own palette. Without the mirror, `ls` inside nvim is visibly punchier
  than the same command in a bare pane.
- **`g:terminal_color_*` is read at terminal creation.** Reopen existing terminal buffers after a
  switch if an application has already copied the palette into truecolour output.
- **A plain `:terminal` misses `TerminalNormal`.** Only snacks-created terminals get the
  `winhighlight`, so a bare `:terminal` shows the editor foreground rather than white.
- **Dark comments are the one poor value left**, at `#5c6370` / 2.32:1 — below the WCAG 3:1 floor, and
  the lighter body text widens the gap. onedark's own `light_grey` `#848b98` is 4.08:1 if it ever
  becomes annoying. Left alone on purpose.
- **`[delta "tokyonight"]` in `src/.gitconfig` is dead config** — a third scheme's worth of
  hardcoded hex from a tokyonight era. delta is never enabled (no `core.pager`, no
  `interactive.diffFilter`, no `features`, and nothing references the block), so it has no effect.
  Delete it, or wire delta up and restyle it to match, but don't treat it as live.
