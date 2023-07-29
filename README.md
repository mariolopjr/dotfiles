# dotfiles

My personal dotfiles repo, managed by the wonderful [chezmoi](https://github.com/twpayne/chezmoi)

As you can tell from the dotfiles, my main setup is macOS. I use Docker and DevContainers heavily, so having macOS, Windows, WSL, DevContainers, Linux, and all my servers use the same dotfiles makes my life easier. It's taken me a long time to finally get to the point of just sitting down and doing this.

## macOS
```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install chezmoi
chezmoi --init --apply mariolopjr
```

## Windows

```
winget install twpayne.chezmoi
chezmoi --init --apply mariolopjr
```

## WSL

```
~> sudo zypper update
~> sudo zypper install -y git chezmoi
~> chezmoi --init --apply mariolopjr
```

## DevContainer

TBD

## Linux

TBD
