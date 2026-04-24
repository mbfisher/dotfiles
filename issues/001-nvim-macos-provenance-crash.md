# macOS `com.apple.provenance` crashes nvim on dlopen

**Date:** 2026-02-13
**Symptoms:** Nvim crashes ~20 seconds after launch, typically when an autocomplete popup appears or a treesitter parser loads. The crash is a hard SIGKILL, not a Lua error.
**Environment:** macOS 26 (Tahoe), Homebrew nvim, Ghostty terminal

## Root Cause

macOS 26 aggressively enforces code signing on dynamically loaded libraries (`.so`/`.dylib`). The chain of failure:

1. **Ghostty** (installed via Homebrew/download) gets tagged with `com.apple.provenance` extended attribute by macOS
2. **Every process Ghostty spawns** (zsh, nvim, cc, etc.) inherits the provenance tag
3. **Every file those processes create** also inherits it — including locally compiled treesitter `.so` parsers and the blink.cmp Rust `.dylib`
4. When nvim calls `dlopen()` on these libraries, macOS validates the code signature, sees the provenance tag marking them as "from an untrusted source", and **kills the process** with `EXC_BAD_ACCESS / SIGKILL (Code Signature Invalid)`

The crash reports show `"termination": {"namespace": "CODESIGNING", "indicator": "Invalid Page"}` and the faulting region is always a `.so` or `.dylib` in `~/.local/share/nvim/`.

## Red Herrings

- **blink.cmp's Rust fuzzy matcher** — early investigation pointed to `libblink_cmp_fuzzy.dylib` specifically, and issues like [blink.cmp #2031](https://github.com/saghen/blink.cmp/issues/2031) and [#2056](https://github.com/Saghen/blink.cmp/issues/2056) describe crashes in the fuzzy matcher. But those are Rust panics (index out of bounds), not macOS SIGKILL. Switching to `fuzzy = { implementation = "lua" }` only moved the crash to the next `dlopen` call (treesitter's `go.so`).
- **Stripping xattr from individual `.so` files** — doesn't work because the running shell (spawned by tainted Ghostty) re-applies provenance to everything it touches.
- **Gatekeeper cache** — even after stripping xattrs, Gatekeeper caches the code signature rejection. Use `codesign --force --sign -` to clear the cache without needing to delete and recompile. See [uv #16726](https://github.com/astral-sh/uv/issues/16726).

## Prevention

Add Ghostty to **System Settings → Privacy & Security → Developer Tools** and enable the toggle. This stops macOS from propagating `com.apple.provenance` to files created by Ghostty's process tree. See [Ghostty discussion #4787](https://github.com/ghostty-org/ghostty/discussions/4787).

## Fix

Run `~/bin/fix-macos-provenance.sh` from **Terminal.app** (not Ghostty or any other Homebrew-installed terminal, since those also have provenance). The script strips provenance from Ghostty/nvim and re-signs tainted `.so`/`.dylib` files with `codesign --force --sign -` to clear the Gatekeeper cache.

Then quit Ghostty completely and relaunch it.

## Recurrence

This will come back after:
- `brew upgrade neovim` (re-tags nvim binary)
- Ghostty updates (re-tags Ghostty.app)
- macOS system updates (can re-apply provenance to existing apps)
- Any `:Lazy sync` / `:TSUpdate` if done from a tainted process

Run `~/bin/fix-macos-provenance.sh` to fix it. If the current terminal is tainted, run it from Terminal.app instead. With Developer Tools enabled for Ghostty, this should only be needed after brew upgrades or macOS updates.

## Diagnosis Checklist

If nvim is crashing with no Lua error (just "Press ENTER" or a hard crash):

1. Check `~/Library/Logs/DiagnosticReports/nvim-*.ips` for recent crashes
2. Look for `"namespace": "CODESIGNING"` in the crash report
3. Check `xattr /opt/homebrew/bin/nvim` — if `com.apple.provenance` is present, this is the issue
4. Check `xattr /Applications/Ghostty.app/Contents/MacOS/ghostty` — if present, the whole process tree is tainted
5. Run `~/bin/fix-macos-provenance.sh` (from Terminal.app if needed), restart Ghostty, reopen nvim
