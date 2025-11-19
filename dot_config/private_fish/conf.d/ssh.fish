# set up ssh-agent with ksshaskpass on KDE
if type -q ksshaskpass
    set -gx SSH_ASKPASS (which ksshaskpass)
    set -gx SSH_ASKPASS_REQUIRE prefer
end

