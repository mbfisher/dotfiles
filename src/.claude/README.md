# ~/.claude

Only the files in this directory are symlinked into `~/.claude` (per-file, one-way, repo -> home;
see `sync.sh`). Everything else in `~/.claude` stays local to the machine.

## Why `settings.json` is not here

`~/.claude/settings.json` is machine-specific. It holds things that differ between machines or
should never be committed:

- `enabledPlugins` and `extraKnownMarketplaces`, which depend on what is installed locally
- permission allowlists tuned to local paths and tools
- `autoMode` environment descriptions for the repos on that machine
- hooks that reference local apps and scripts

Symlinking it would either break other machines or leak local detail into a public repo.

## Settings worth copying by hand

Some keys in `settings.json` are preferences we want everywhere, but they have to be duplicated
manually on each machine:

```json
{
  "model": "opus"
}
```

- `model` sets the default model for new sessions (desktop app and terminal). Subagents inherit it.

When adding a new shared preference, record it here so it can be reproduced on the next machine.
