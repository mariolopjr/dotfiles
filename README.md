# dotfiles

My personal dotfiles repo, managed by the wonderful [chezmoi](https://github.com/twpayne/chezmoi)

## Linux

### winterfell (desktop)

#### Setup dotfiles
Chezmoi should be already installed via the bootstrap file
```bash
chezmoi init --apply mariolopjr
chezmoi cd
git remote set-url origin git@github.com:mariolopjr/dotfiles.git
```

## macOS

### dragonstone (laptop)

#### Setup Linux dotfiles
TBD

### targaryen (laptop)

#### Setup macOS dotfiles

```zsh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install chezmoi
chezmoi init --apply mariolopjr
chezmoi cd
git remote set-url origin git@github.com:mariolopjr/dotfiles.git
```

## Todo

- configuration for steam deck
- configuration for nas
- configuration for pi
- configuratiion for asahi

