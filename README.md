# dotfiles

My personal dotfiles repo, managed by the wonderful [chezmoi](https://github.com/twpayne/chezmoi)

## macOS

Both my desktop and laptop run macOS, so setting up the dotfiles is quite trivial and is the main OS supported.

### stark (desktop)

### targaryen (laptop)

#### Setup macOS dotfiles

```zsh
sudo softwareupdate --install-rosetta
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
brew install chezmoi
chezmoi init --apply mariolopjr
chezmoi cd
git remote set-url origin git@github.com:mariolopjr/dotfiles.git
```

Sometimes, fisher plugin install is wonky. If so, ensure chezmoi overwrites the `fish_plugins` file, manually run `fisher update`, then run `chezmoi apply` again to complete setup.

#### Setup Linux dotfiles

TBD

## Todo

- configuration for steam deck
- configuration for nas
