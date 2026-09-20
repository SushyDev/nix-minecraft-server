super basic minecraft server managed in nix and hosted on docker.

## Mods & versions

`mods.json` is the single source of truth: Fabric loader/installer/server jar,
and every mod (Modrinth project id + resolved version/url/sha256). `flake.nix`
reads it directly — nothing else needs editing to bump a mod.

To add a mod, add `{"name": ..., "project": "<modrinth project id>"}` to the
`mods` list in `mods.json` and run the updater.

### Updating

- `nix run .#update` — refresh every mod + the Fabric server to the latest
  build for the *current* `minecraft_version` (patch/incremental update).
- `nix run .#update -- 26.4` — move to a new `minecraft_version` (major
  update). Mods with no Fabric build for that version are left untouched and
  reported instead of failing the whole run.

### CI

- **Update mods (incremental)** — runs weekly (and on demand), commits any
  `mods.json` changes to a branch, and opens a **draft release** summarizing
  what changed / what couldn't be updated.
- **Update mods (major version)** — manual, same flow, for jumping to a new
  Minecraft version.
- **docker-image** — fires when a draft release above is *promoted* (published)
  in the GitHub UI. Fast-forwards `main` to that release's commit, builds the
  multi-arch image with Nix, and pushes it to GHCR tagged `latest`, the
  Minecraft version (e.g. `26.3`), and the release tag.

