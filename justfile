# PKGBUILDs I maintain. One directory per package, driven by `just`.
#
# A package is any first-level directory containing a PKGBUILD, and that
# directory's name must match the PKGBUILD's pkgbase.
#
# Builds stay out of tree: makepkg always runs with PKGDEST/SRCDEST/BUILDDIR
# pointing into .build/, so package directories only ever hold sources.
#
# Note: in this justfile, `setup` below is a literal string (just does not
# interpolate inside block strings), so the recipes pass ROOT and the
# makepkg directories to it as shell variables.

set shell := ["bash", "-euo", "pipefail", "-c"]

root     := justfile_directory()
outdir   := root + "/.build"
pkgdest  := env_var_or_default("PKGDEST", outdir + "/pkg")
srcdest  := env_var_or_default("SRCDEST", outdir + "/src")
builddir := env_var_or_default("BUILDDIR", outdir + "/staging")

# Flags passed to makepkg when building: MAKEPKGFLAGS="--noconfirm" just build
makepkg_flags := env_var_or_default("MAKEPKGFLAGS", "-sf")

# Shared prologue for build and install: selects the packages to act on.
# Uses $ROOT, $PKGDEST, $SRCDEST, $BUILDDIR and $PKG, all set by the caller,
# and leaves the result in ${targets[@]}.
setup := """
    cd "$ROOT"
    mkdir -p "$PKGDEST" "$SRCDEST" "$BUILDDIR"
    mapfile -t all < <(find . -mindepth 2 -maxdepth 2 -type f -name PKGBUILD \
      | xargs -r -n1 dirname | cut -s -d/ -f2 | grep -vE '^[._]' | sort)
    if [[ -n "$PKG" ]]; then
      targets=("$PKG")
    elif (( ${#all[@]} )); then
      targets=("${all[@]}")
    else
      echo "no packages yet: a package is a directory containing a PKGBUILD"
      exit 0
    fi
    for t in "${targets[@]}"; do
      if [[ ! -f "$t/PKGBUILD" ]]; then
        echo "error: no package named $t" >&2
        echo "available: ${all[*]:-none}" >&2
        exit 1
      fi
    done
    """

# List the rules, then the packages.
default:
    @just --justfile "{{ root }}/justfile" --list --unsorted

# List the packages in this repository.
list:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ root }}"
    mapfile -t all < <(find . -mindepth 2 -maxdepth 2 -type f -name PKGBUILD \
      | xargs -r -n1 dirname | cut -s -d/ -f2 | grep -vE '^[._]' | sort)
    if (( ${#all[@]} )); then
      printf '  %s\n' "${all[@]}"
    else
      echo "  (no packages yet)"
    fi

# Build a package, or every package if none is given.
build package='':
    #!/usr/bin/env bash
    set -euo pipefail
    ROOT="{{ root }}"
    export PKGDEST="{{ pkgdest }}" SRCDEST="{{ srcdest }}" BUILDDIR="{{ builddir }}"
    PKG={{ quote(package) }}
    {{ setup }}
    for t in "${targets[@]}"; do
      echo
      echo "==> building $t"
      ( cd "$t" && makepkg {{ makepkg_flags }} )
    done

# Install a package with pacman, building it first when needed.
# Without an argument, builds and installs every package in the repository.
install package='':
    #!/usr/bin/env bash
    set -euo pipefail
    ROOT="{{ root }}"
    export PKGDEST="{{ pkgdest }}" SRCDEST="{{ srcdest }}" BUILDDIR="{{ builddir }}"
    PKG={{ quote(package) }}
    {{ setup }}
    files=()
    for t in "${targets[@]}"; do
      # makepkg knows which files a build produces, split packages and
      # -debug packages included.
      mapfile -t want < <( cd "$t" && makepkg --packagelist )
      need=0
      for f in "${want[@]}"; do [[ -f "$f" ]] || need=1; done
      if (( need )); then
        echo "==> $t is not built yet, building it first"
        ( cd "$t" && makepkg {{ makepkg_flags }} )
        for f in "${want[@]}"; do
          [[ -f "$f" ]] || { echo "error: the build did not produce $f" >&2; exit 1; }
        done
      fi
      files+=("${want[@]}")
    done
    echo
    echo "==> installing ${#files[@]} file(s)"
    sudo pacman -U -- "${files[@]}"
