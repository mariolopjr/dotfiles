if status is-interactive
    # Commands to run in interactive sessions can go here
end

## Source custom configs
for file in $__fish_config_dir/custom.d/*.fish
    source $file
end

## Launch homebrew on macOS
if type -q /opt/homebrew/bin/brew
    eval (/opt/homebrew/bin/brew shellenv fish)
end

## Launch homebrew on linux
if type -q /home/linuxbrew/.linuxbrew/bin/brew
    eval (/home/linuxbrew/.linuxbrew/bin/brew shellenv fish)
end

## Launch The Fuck
if type -q thefuck
    thefuck --alias | source
end

## Launch zoxide
if type -q zoxide
    zoxide init fish | source
end

## Launch direnv
if type -q direnv
    direnv hook fish | source
end

## Load asdf
if type -q asdf
    source $(brew --prefix)/opt/asdf/libexec/asdf.fish
end

## add llvm to path
fish_add_path $(brew --prefix)/opt/llvm/bin
