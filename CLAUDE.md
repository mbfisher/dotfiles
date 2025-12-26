This is a "dotfiles" repository of user-specific configuration for MacOS. I'm  a professional software engineer.

## Configuration

The src/ directory contains files that symlinked in to my HOME directory eg:

~/.zshrc -> src/.zshrc

src/.config works slightly differently, in that we link entire subdirectories rather than their contents:

~/.config/nvim -> src/.config/nvim

## Peripherals

I use a Keychron K3 Max keyboard and Keychron M6 mouse. They need some custom configuration for my setup. See src/.config/karabiner/README.md
