function pkg-audit --description 'Report drift between packages.toml and installed brew/cask/mas, prints only'
    if not type -q brew; or not type -q chezmoi
        echo "pkg-audit: needs brew and chezmoi" >&2
        return 1
    end

    set -l declared_brews (chezmoi execute-template '{{ range .packages.darwin.brews }}{{ . }}
{{ end }}')
    set -l declared_casks (chezmoi execute-template '{{ $all := concat .packages.darwin.casks (dig .chezmoi.hostname "casks" (list) .packages.darwin.hosts) }}{{ range $all }}{{ . }}
{{ end }}')
    set -l declared_mas (chezmoi execute-template '{{ range .packages.darwin.mas }}{{ .id }}
{{ end }}')

    set -l installed_casks (brew list --cask)

    # brews compare against different installed lists per direction, declared deps
    # like fish and libpng are not leaves so "missing" must check the full list,
    # while "extra" only cares about top-level installed-on-request formulae
    echo "== brews =="
    echo "  missing (declared, not installed):"
    comm -23 (printf '%s\n' $declared_brews | sort -u | psub) (brew list --formula --full-name | sort -u | psub) | string replace -r '^' '    '
    echo "  extra (installed on request, not declared):"
    comm -13 (printf '%s\n' $declared_brews | sort -u | psub) (brew leaves --installed-on-request | sort -u | psub) | string replace -r '^' '    '

    echo "== casks =="
    echo "  missing (declared, not installed):"
    comm -23 (printf '%s\n' $declared_casks | sort -u | psub) (printf '%s\n' $installed_casks | sort -u | psub) | string replace -r '^' '    '
    echo "  extra (installed, not declared):"
    comm -13 (printf '%s\n' $declared_casks | sort -u | psub) (printf '%s\n' $installed_casks | sort -u | psub) | string replace -r '^' '    '

    if type -q mas
        # mas names are not unique so compare by numeric id, print names for context
        set -l mas_installed (mas list)
        echo "== mac app store =="
        echo "  missing (declared, not installed):"
        comm -23 (printf '%s\n' $declared_mas | sort -u | psub) (printf '%s\n' $mas_installed | awk '{print $1}' | sort -u | psub) | string replace -r '^' '    '
        echo "  extra (installed, not declared):"
        for id in (comm -13 (printf '%s\n' $declared_mas | sort -u | psub) (printf '%s\n' $mas_installed | awk '{print $1}' | sort -u | psub))
            printf '%s\n' $mas_installed | awk -v id=$id '$1 == id {print "    " $0}'
        end
    end
end
