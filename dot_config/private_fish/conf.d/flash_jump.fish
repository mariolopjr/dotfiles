status is-interactive; or return

# flash-style label jump: alt-s paints a label over each word's first char,
# press the label to move the cursor there. one keypress, then the mode ends.
# alt-s shadows fish's default sudo-prepend binding.

set -g flash_jump_labels f j d k s l a g h w e r u i o p

function flash-jump --description 'label jump to a word on the command line'
    set -l buf (commandline)
    test -n "$buf"; or return
    set -g __flash_buf $buf
    set -g __flash_origin (commandline -C)

    # 0-indexed offset of each whitespace-delimited word's first char
    set -g __flash_starts
    for m in (string match --all --index --regex '\S+' -- $buf)
        set -a __flash_starts (math (string split -f1 ' ' $m) - 1)
    end

    set -l n (count $__flash_starts)
    test $n -gt 1; or return
    set -l max (count $flash_jump_labels)
    if test $n -gt $max
        set __flash_starts $__flash_starts[1..$max]
        set n $max
    end

    set -l painted $buf
    for i in (seq $n)
        set -l off $__flash_starts[$i]
        set painted (string sub -l $off -- $painted)(string upper $flash_jump_labels[$i])(string sub -s (math $off + 2) -- $painted)
    end

    commandline --replace -- $painted
    commandline -C $__flash_origin
    set fish_bind_mode flash
    commandline -f repaint-mode
end

function _flash_land --description 'restore the command line and move to the chosen word, or abort'
    set -l dest $__flash_origin
    if set -q argv[1]; and test -n "$argv[1]"; and test $argv[1] -le (count $__flash_starts)
        set dest $__flash_starts[$argv[1]]
    end
    commandline --replace -- $__flash_buf
    commandline -C $dest
    set -e __flash_buf __flash_origin __flash_starts
end

# Re-apply on every bindings init so a mode switch or fish_default_key_bindings
# does not drop these, matching autopair and puffer in this config
function _flash_jump_bindings --on-variable fish_key_bindings
    # flash mode: labels land on a word, everything else aborts without inserting.
    # printable keys self-insert unless explicitly bound, so bind them all.
    for i in (seq (count $flash_jump_labels))
        set -l lbl $flash_jump_labels[$i]
        bind -M flash -m default $lbl "_flash_land $i"
        bind -M flash -m default (string upper $lbl) "_flash_land $i"
    end

    for c in (string split '' abcdefghijklmnopqrstuvwxyz)
        contains -- $c $flash_jump_labels; and continue
        bind -M flash -m default $c _flash_land
        bind -M flash -m default (string upper $c) _flash_land
    end

    for d in 0 1 2 3 4 5 6 7 8 9
        bind -M flash -m default $d _flash_land
    end

    bind -M flash -m default escape _flash_land
    bind -M flash -m default ctrl-c _flash_land
    bind -M flash -m default enter _flash_land
    bind -M flash -m default ' ' _flash_land
    bind -M flash -m default '' _flash_land

    # sudo-prepend, relocated from its default alt-s which flash-jump now takes
    set -l prepend 'for cmd in sudo doas please run0; if command -q $cmd; fish_commandline_prepend $cmd; break; end; end'

    # default mode covers the emacs bindings, insert mode covers vi and hybrid
    bind alt-s flash-jump
    bind alt-S flash-jump
    bind alt-p $prepend
    if contains -- "$fish_key_bindings" fish_vi_key_bindings fish_hybrid_key_bindings
        bind -M insert alt-s flash-jump
        bind -M insert alt-S flash-jump
        bind -M insert alt-p $prepend
    end
end

_flash_jump_bindings
