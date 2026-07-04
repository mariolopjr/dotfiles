function mise-up --description 'Preview then upgrade mise tools pinned to latest'
    echo "mise upgrade --dry-run $argv:"
    mise upgrade --dry-run $argv; or return $status
    echo
    read -l -P 'apply these upgrades? [y/N] ' reply
    switch $reply
        case Y y yes
            mise upgrade $argv
        case '*'
            echo skipped
    end
end
