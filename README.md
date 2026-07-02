# dotfiles

My personal dotfiles repo, managed by the wonderful [chezmoi](https://github.com/twpayne/chezmoi)

## Layout

| Path | Purpose |
| --- | --- |
| `.chezmoidata/packages.toml` | Single source of truth for brew taps, packages, casks, and Mac App Store apps, including per-host extras |
| `.chezmoiscripts/` | Install and configuration scripts, see naming below |
| `dot_config/nvim/` | Neovim config, `lua/config` for core settings, `lua/plugins` for lazy.nvim specs, `lua/plugins/lang` for language-specific plugins |
| `dot_config/private_fish/` | Fish shell config, plugins in `fish_plugins`, abbreviations in `abbrfile` |
| `dot_hammerspoon/` | Hammerspoon config |
| `private_Library/` | App configs that live under `~/Library` |

### Packages

All machine packages live in `.chezmoidata/packages.toml`. To add one, add it
to the right list and run `chezmoi apply`. Host-specific casks go under
`[packages.darwin.hosts.<hostname>]`.

### Scripts

Scripts use chezmoi's naming conventions:

- `run_onchange_before_*` runs before files are applied whenever its rendered
  content changes, package installs re-run automatically when
  `packages.toml` changes
- `run_onchange_after_*` runs after files are applied, the fisher and mise
  scripts embed a hash of their config file so they re-run when it changes
- `run_once_*` runs a single time, used for one-shot setup like the tide
  prompt

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

## Todo

- configure macos spaces for easy switching
- configure macos system and user settings
- configuration for steam deck
- configuration for nas
- bazzite box (storms-end): LACT + coolercontrol for GPU and fans, sunshine
  via `ujust setup-sunshine`, kargs `modules-load=nct6775`
