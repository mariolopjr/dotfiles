if status is-interactive
  # Commands to run in interactive sessions can go here
end

## Source custom configs
for file in $__fish_config_dir/custom.d/*.fish
  source $file
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
  source "(brew --prefix asdf)"/libexec/asdf.fish
end
