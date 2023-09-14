# dotfiles

My personal dotfiles repo, managed by the wonderful [chezmoi](https://github.com/twpayne/chezmoi)

As you can tell from the dotfiles, my main setup is Windows and WSL. I use Docker and DevContainers heavily, so having Windows, WSL, macOS, DevContainers, Linux, and all my servers use the same dotfiles makes my life easier. It's taken me a long time to finally get to the point of just sitting down and doing this.

## Windows

### winterfell

#### Setup Windows dotfiles

```powershell
PS C:\Users\mario> winget install twpayne.chezmoi
PS C:\Users\mario> chezmoi init --apply mariolopjr
PS C:\Users\mario> git remote set-url origin git@github.com:mariolopjr/dotfiles.git
```

## WSL

### Ubuntu (Preview)

#### Setup WSL dotfiles

```bash
mario@winterfell:~$ sudo apt update && sudo apt install build-essential procps curl file git
mario@winterfell:~$ /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
mario@winterfell:~$ brew install chezmoi
mario@winterfell:~$ chezmoi init --apply mariolopjr
```

#### Upgrade release

```zsh
sudo apt update && sudo do-release-upgrade
```

## macOS

### targaryen

#### Setup macOS dotfiles

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

- Windows
  - Install packages with winget configuration file (sadly requires preview winget which won't automatically update)
  - git aliases for powershell/zsh
  - move from fish to zsh on macOS
