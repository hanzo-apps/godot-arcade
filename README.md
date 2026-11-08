# Orb Runner — Godot 4 web export

<!-- hanzo-badges -->
<p align="left">
  <a href="https://platform.hanzo.ai/new?repo=https%3A%2F%2Fgithub.com%2Fhanzo-apps%2Fgodot-arcade&template=godot-arcade"><img src="https://gallery.hanzo.ai/deploy.svg" alt="Deploy to Hanzo" height="32" /></a>
  <a href="https://hanzo.ai/chat?template=godot-arcade"><img src="https://gallery.hanzo.ai/badges/edit-in-hanzo.svg" alt="Edit in Hanzo.ai" height="32" /></a>
  <a href="https://gallery.hanzo.ai/templates/godot-arcade"><img src="https://gallery.hanzo.ai/badges/live-preview.svg" alt="Live Preview" height="32" /></a>
  <a href="https://gallery.hanzo.ai/llms/godot-arcade/LLM.md"><img src="https://gallery.hanzo.ai/badges/llm-md.svg" alt="LLM.md Playbook" height="32" /></a>
</p>
<!-- /hanzo-badges -->

A complete 3D arcade game in ~150 lines of GDScript, exported to WebAssembly. Roll the
sphere, collect orbs, don't fall off the arena. The whole world is built in code, so the
repo has no binary scenes to merge-conflict on.

Live: https://godot-arcade.hanzo.app

## Build

Needs Godot 4.4 + the matching export templates (`~/.local/share/godot/export_templates/4.4.stable`).

```sh
godot --headless --import .
# fingerprint the export basename: every sibling asset inherits it, so index.js/.wasm/.pck
# become content-addressed names the CDN can cache forever without ever going stale
V=$(cat world.gd main.tscn project.godot | sha256sum | cut -c1-8)
godot --headless --export-release "Web" build/orb-$V.html
cp build/orb-$V.html build/index.html
```

`export_presets.cfg` ships `thread_support=false`: the non-threaded export runs on every
browser including iOS Safari. Flip it to `true` for the threaded build — hanzo.app already
serves the COOP/COEP that SharedArrayBuffer requires when the project declares
`"framework": "godot"`.

## Deploy to hanzo.app

An engine build is far bigger than the 4 MiB the public edge accepts in one request
body, so games ship through the **release lane**, not the artifact lane: put the built
tree in your object space, then publish it server-side.

```sh
# 1. declare the engine — `unity`, `unreal`, `godot` make clients/sites serve the
#    site cross-origin-isolated (COOP/COEP) so multithreaded WASM gets SharedArrayBuffer
curl -X POST https://api.hanzo.ai/v1/projects -H "Authorization: Bearer $TOKEN" \
  -H "X-Org-Id: $ORG" -H "Content-Type: application/json" \
  -d "{\"slug\":\"my-game\",\"name\":\"my-game\",\"framework\":\"godot\"}"

# 2. stage the build to s3.hanzo.ai under <org>/_stage/my-game/
# 3. promote it into an immutable content-addressed release + flip the pointer
curl -X POST https://api.hanzo.ai/v1/sites/my-game/publish -H "Authorization: Bearer $TOKEN" \
  -H "X-Org-Id: $ORG" -H "Content-Type: application/json" -d "{\"source\":\"_stage/my-game\"}"
```

**Fingerprint your asset names.** The site server serves a content-hashed filename
`immutable` and everything else with a plain `max-age`. A redeploy that reuses the same
asset name leaves browsers and the CDN running the OLD loader against the NEW binary —
for a WASM app that is a silent, permanent hang with no error, not a visible failure.

## License

MIT (this game). Godot Engine is MIT, (c) the Godot Engine contributors.
