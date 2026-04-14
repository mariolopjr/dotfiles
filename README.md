# dotfiles

My personal dotfiles repo, managed by the wonderful [chezmoi](https://github.com/twpayne/chezmoi)

## macOS

Both my desktop and laptop run macOS, so setting up the dotfiles is quite trivial and is the main OS supported.

### winterfell (desktop)

### dragonstone (laptop)

#### Setup macOS dotfiles

```zsh
sudo softwareupdate --install-rosetta
sudo scutil --set HostName HOSTNAME
ssh-keygen -t ed25519 -C "EMAIL"
eval "$(ssh-agent -s)"
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
brew install chezmoi
chezmoi init --apply mariolopjr
chezmoi cd
git remote set-url origin git@github.com:mariolopjr/dotfiles.git
```

### storms-end

#### Setup Linux dotfiles

*storms-end* is my main gaming PC running bazzite-nvidia-deck, so not much needs
to be configured. The dotfiles are minimal -- mainly to configure LACT and
Cooler Control fans, as well as load a module for fan support.

Since it's sole purpose is gaming, minimal dots are included, and Gaming Mode is
the default.

```bash
chezmoi init --apply mariolopjr
```

## Todo

- configure macos spaces for easy switching
- configure macos system and user settings
- configuration for steam deck
- configuration for nas
