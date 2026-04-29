# Canonical HeelKawn repository

This document fixes **where** official HeelKawn work lives so history is not split across folders or remotes.

## Official remote

| | |
|--|--|
| **GitHub** | `https://github.com/PVAGR/HeelKawn1` |
| **Default branch** | `main` |
| **Clone destination (this machine)** | `C:\Users\user\Documents\GitHub\HeelKawn1` |

Anything committed and pushed to **`main`** on that remote is the **record of record** for the Godot simulation, docs, and tooling in this project.

## What counts as canonical

- **Yes:** The working tree at `HeelKawn1` whose `origin` remote is exactly `PVAGR/HeelKawn1.git` on GitHub (fetch/push URLs may use `https://github.com/PVAGR/HeelKawn1.git`).
- **No:** Other folders named similarly (`Heel-Kawn`, `HeelKawn`, old exports, Downloads copies, Documents duplicates) unless you are deliberately **one-time migrating** files into this repo with a tracked commit message.

Do not edit “another HeelKawn” thinking it syncs automatically—**only commits on this repo** update GitHub history.

## How memory stays forever

Software does not disappear from GitHub unless the repository is deleted or made private/offline. Your durable trail is:

1. **Working changes** → `git add` / `git commit`
2. **Publish** → `git push origin main`

IDEs and assistants should **prefer committing** meaningful chunks with clear messages rather than letting work sit unstaged only on disk.

## Other HeelKawn-shaped projects

Legacy stream/mod repos, forks, or experimental trees may exist elsewhere. Treat them as **historical or parallel** unless you explicitly adopt their files here. Integration = copy into **this** tree + commit + push **here**.

---

Last updated when repository scope policy changes (not every feature commit).
