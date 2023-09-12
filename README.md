# dotfiles

My personal dotfiles repo, managed by the wonderful [chezmoi](https://github.com/twpayne/chezmoi)

As you can tell from the dotfiles, my main setup is Windows and WSL. I use Docker and DevContainers heavily, so having Windows, WSL, macOS, DevContainers, Linux, and all my servers use the same dotfiles makes my life easier. It's taken me a long time to finally get to the point of just sitting down and doing this.

## Windows

### winterfell

```
winget install twpayne.chezmoi
chezmoi init --apply mariolopjr
git remote set-url origin git@github.com:mariolopjr/dotfiles.git
```

## WSL (Ubuntu Preview)

```zsh
~> sudo apt update
~> sudo apt install -y git chezmoi
~> chezmoi init --apply mariolopjr
```

## macOS

### targaryen

```zsh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install chezmoi
chezmoi init --apply mariolopjr
git remote set-url origin git@github.com:mariolopjr/dotfiles.git
```

## DevContainer

TBD

## Linux

TBD

## Todo

- For Windows, opt-out of telemetry `DOTNET_CLI_TELEMETRY_OPTOUT`
