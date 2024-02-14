# dotfiles

My personal dotfiles repo, managed by the wonderful [chezmoi](https://github.com/twpayne/chezmoi)

As you can tell from the dotfiles, my main setup is macOS. I mainly use `asdf` for managing dependencies (having moved away from a mostly Docker-based workflow). I do have a gaming desktop (for now), will need to tweak it for streaming.

## macOS

### targaryen (laptop, mbp m1 pro 14")

#### Setup macOS dotfiles

```zsh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install chezmoi
chezmoi init --apply mariolopjr
chezmoi cd
git remote set-url origin git@github.com:mariolopjr/dotfiles.git
```

## Windows

### winterfell (desktop, custom)

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

## Linux

TBD

## Todo

- WSL
  - move to fish
- neovim
  - clipboard and default register sync
