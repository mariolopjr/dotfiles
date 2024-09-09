# dotfiles

My personal dotfiles repo, managed by the wonderful [chezmoi](https://github.com/twpayne/chezmoi)

As you can tell from the dotfiles, my main setup is macOS. I mainly use `asdf` for managing dependencies (having moved away from a mostly Docker-based workflow). I do have a gaming desktop (for now), will need to tweak it for streaming.

## macOS

### targaryen (laptop)

#### Setup macOS dotfiles

```zsh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install chezmoi
chezmoi init --apply mariolopjr
chezmoi cd
git remote set-url origin git@github.com:mariolopjr/dotfiles.git
```

## Linux

TBD

## Todo

- linux configuration for nas
- neovim
  - clipboard and default register sync
