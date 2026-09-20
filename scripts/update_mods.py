#!/usr/bin/env python3
"""
Update mods.json: re-resolves the Fabric server/loader/installer and every
mod's latest Modrinth build for a target Minecraft version.

Usage:
  update_mods.py                 # refresh everything for the current minecraft_version
  update_mods.py 26.3            # move to a new minecraft_version (major update)

To track a new mod, add {"name": ..., "project": <modrinth project id>} to
mods.json's "mods" list (version/url/sha256 can be left empty) and run this
script.

Writes mods.json in place and prints a markdown summary (also written to
update-summary.md for CI to pick up).
"""
import json
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

MODS_JSON = "mods.json"
SUMMARY_FILE = "update-summary.md"
USER_AGENT = "nix-minecraft-server-updater/1.0 (github.com)"


def http_get_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as e:
        if e.code in (400, 404):
            return []
        raise


def prefetch_sha256(url):
    hash32 = subprocess.run(
        ["nix-prefetch-url", url], capture_output=True, text=True, check=True
    ).stdout.strip().splitlines()[-1]
    sri = subprocess.run(
        ["nix", "hash", "convert", "--hash-algo", "sha256", "--to", "sri", hash32],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    return sri


def resolve_fabric_loader(mc_version):
    loaders = http_get_json(f"https://meta.fabricmc.net/v2/versions/loader/{mc_version}")
    stable = [entry for entry in loaders if entry["loader"]["stable"]]
    chosen = (stable or loaders)
    if not chosen:
        return None
    return chosen[0]["loader"]["version"]


def resolve_fabric_installer():
    installers = http_get_json("https://meta.fabricmc.net/v2/versions/installer")
    stable = [entry for entry in installers if entry["stable"]]
    chosen = (stable or installers)[0]
    return chosen["version"]


def resolve_mod_version(project, mc_version):
    query = urllib.parse.urlencode({
        "loaders": json.dumps(["fabric"]),
        "game_versions": json.dumps([mc_version]),
    })
    url = f"https://api.modrinth.com/v2/project/{project}/version?{query}"
    versions = http_get_json(url)
    if not versions:
        return None
    latest = versions[0]
    files = latest.get("files", [])
    primary = next((f for f in files if f.get("primary")), files[0] if files else None)
    if primary is None:
        return None
    return {"version": latest["version_number"], "url": primary["url"]}


def main():
    with open(MODS_JSON) as f:
        data = json.load(f)

    target_mc = sys.argv[1] if len(sys.argv) > 1 else data["minecraft_version"]
    data["minecraft_version"] = target_mc

    report_lines = [f"## Mod update report for Minecraft {target_mc}\n"]
    skipped = []
    changed = []

    loader_version = resolve_fabric_loader(target_mc)
    if loader_version is None:
        print(f"error: no Fabric loader available for Minecraft {target_mc}", file=sys.stderr)
        sys.exit(1)
    installer_version = resolve_fabric_installer()

    server_url = (
        f"https://meta.fabricmc.net/v2/versions/loader/"
        f"{target_mc}/{loader_version}/{installer_version}/server/jar"
    )
    old_server_url = data["fabric"].get("server_url")
    server_sha256 = prefetch_sha256(server_url)

    if server_url != old_server_url:
        changed.append(
            f"- **fabric server**: loader `{data['fabric'].get('loader')}` -> `{loader_version}`, "
            f"installer `{data['fabric'].get('installer')}` -> `{installer_version}`"
        )
    data["fabric"]["loader"] = loader_version
    data["fabric"]["installer"] = installer_version
    data["fabric"]["server_url"] = server_url
    data["fabric"]["server_sha256"] = server_sha256

    for mod in data["mods"]:
        resolved = resolve_mod_version(mod["project"], target_mc)
        if resolved is None:
            skipped.append(mod["name"])
            continue
        if resolved["version"] != mod.get("version"):
            changed.append(
                f"- **{mod['name']}**: `{mod.get('version')}` -> `{resolved['version']}`"
            )
        mod["version"] = resolved["version"]
        mod["url"] = resolved["url"]
        mod["sha256"] = prefetch_sha256(resolved["url"])

    with open(MODS_JSON, "w") as f:
        json.dump(data, f, indent="\t")
        f.write("\n")

    if changed:
        report_lines.append("### Updated\n")
        report_lines.extend(changed)
    else:
        report_lines.append("Nothing changed — everything is already up to date.")

    if skipped:
        report_lines.append("\n### Could not update (no Fabric build for this Minecraft version)\n")
        report_lines.extend(f"- {name}" for name in skipped)

    report = "\n".join(report_lines) + "\n"
    print(report)
    with open(SUMMARY_FILE, "w") as f:
        f.write(report)

    if skipped:
        sys.exit(2)


if __name__ == "__main__":
    main()
