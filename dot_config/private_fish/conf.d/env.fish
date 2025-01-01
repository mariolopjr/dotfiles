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

if type -q brew
  set -gx HOMEBREW_NO_ANALYTICS 1
end
