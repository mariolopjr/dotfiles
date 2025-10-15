# Disable fish greeting
set -g fish_greeting

if type -q nvim
    set -gx EDITOR nvim
    set -gx VISUAL nvim
else if type -q vim
    set -gx EDITOR vim
    set -gx VISUAL vim
else
    set -gx EDITOR vi
    set -gx VISUAL vi
end

if type -q dotnet
    set -gx DOTNET_CLI_TELEMETRY_OPTOUT true
    fish_add_path ~/.dotnet/tools
end

if type -q brew
    set -gx HOMEBREW_NO_ANALYTICS 1
end

if test -d "$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
	fish_add_path "$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
end
