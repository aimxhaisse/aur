# PKGBUILDs

One directory per package, driven by [`just`](https://just.systems).

A package is any first-level directory containing a `PKGBUILD` whose `pkgbase`
matches the directory name; a split `PKGBUILD` (`pkgbase='foo'` producing `foo`,
`foo-doc`, …) stays one directory. Directories starting with `.` or `_` are
ignored.

```
.
├── justfile          # list / build / install
├── <pkgbase>/        # PKGBUILD + patches, .install files, local sources
└── .build/           # generated: pkg/ src/ staging/
```

Builds happen out of tree under `.build/`, so package directories only ever hold
sources.

## Packages

| Package | | Pinned |
| --- | --- | --- |
| [`crit`](crit/) | review AI coding agents' plans, diffs and running apps in the browser ([crit.md](https://crit.md)) | `0.23.2` |

`just list` prints what the repository currently holds.

## Usage

```sh
just                 # list the rules, then the packages
just list

just build           # every package
just build foo       # one package

just install foo     # sudo pacman -U the built files
just install         # every package
```

Both need `sudo`: makepkg installs missing dependencies, and `install` runs
`pacman -U`.

## Requirements

```sh
sudo pacman -S --needed base-devel just
```
