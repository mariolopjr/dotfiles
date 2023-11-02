# dotfiles

My personal dotfiles repo, managed by the wonderful [chezmoi](https://github.com/twpayne/chezmoi)

As you can tell from the dotfiles, my main setup is macOS. I also use Docker when it makes sense, so having macOS, Linux, Containers, Windows, WSL, and all my servers use the same dotfiles makes my life easier. It's taken me a long time to finally get to the point of just sitting down and doing this.

## Windows

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

### winterfell (desktop)

#### Bootstrap system

First, load up Arch Linux on a USB drive and disable Secure Boot. Boot up USB, set root password, connect via SSH, and run this command `bash <(curl -sL git.io/JMnGu)` to bootstrap the system.
TODO: Figure out Secure Boot

Once logged in, use chezmoi to bootstrap dotfiles

```bash
chezmoi init --apply mariolopjr
git remote set-url origin git@github.com:mariolopjr/dotfiles.git
```

## WSL

### Ubuntu (Preview)

#### Setup WSL dotfiles

```bash
mario@winterfell:~$ sudo apt update && sudo apt install build-essential procps curl file git
mario@winterfell:~$ /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
mario@winterfell:~$ eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
mario@winterfell:~$ brew install chezmoi
mario@winterfell:~$ chezmoi init --apply mariolopjr
```

#### Upgrade release

```zsh
sudo apt update && sudo do-release-upgrade
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
- WSL
  - alias certain brew commands to match winget
  - setup completions for zsh
- neovim
  - clipboard and default register sync
