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

#### Setup Linux dotfiles

TBD

#### Notes

Sometimes, fisher plugin install is wonky. If so, ensure chezmoi overwrites the `fish_plugins` file, manually run `fisher update`, then run `chezmoi apply` again to complete setup.

## Todo

- configure and use sketchybar
- configure macos spaces for easy switching
- configuration for steam deck
- configuration for nas
