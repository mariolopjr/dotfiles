# dotfiles

My personal dotfiles repo, managed by the wonderful [chezmoi](https://github.com/twpayne/chezmoi)

As you can tell from the dotfiles, my main setup is Windows. I also use DevContainers/Docker when it makes sense, so having everything use the same dotfiles makes my life easier. It's taken me a long time to finally get to the point of just sitting down and doing this.

## Windows

### winterfell (desktop)

#### Setup dotfiles

```powershell
PS C:\Users\mario> winget install twpayne.chezmoi
PS C:\Users\mario> chezmoi init --apply mariolopjr
PS C:\Users\mario> git remote set-url origin git@github.com:mariolopjr/dotfiles.git
```

## WSL

### OpenSUSE Tumbleweed

#### Setup WSL dotfiles

```bash
mario@winterfell:~$ sudo zypper install git chezmoi
mario@winterfell:~$ chezmoi init --apply mariolopjr
mario@winterfell:~$ chezmoi cd
mario@winterfell:~$ git remote set-url origin git@github.com:mariolopjr/dotfiles.git
```

#### Upgrade release

```zsh
sudo zypper ref -b && sudo zypper dup
```

## DevContainer

TBD

## Linux

TBD

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
