This is a "dotfiles" repository of user-specific configuration for MacOS. I'm a professional software engineer.

## Configuration

The src/ directory contains files that symlinked in to my HOME directory eg:

~/.zshrc -> src/.zshrc

src/.config works slightly differently, in that we link entire subdirectories rather than their contents:

~/.config/nvim -> src/.config/nvim

## Issues

The `issues/` directory at the repo root documents non-trivial debugging investigations. Issues can span multiple
tools (e.g. zsh aliases + zellij + mise) so they live at the top level rather than inside any single config directory.

Each issue file follows the format: symptoms, root cause, red herrings, fix/workaround, recurrence notes. When
resolving a tricky problem, save it as `issues/NNN-short-description.md`. Check existing issues before debugging a
problem that may already be documented.

## Peripherals

I use a Keychron K3 Max keyboard and Keychron M6 mouse. They need some custom configuration for my setup. See src/.config/karabiner/README.md
