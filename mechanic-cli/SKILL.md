---
name: mechanic-cli
description: >
  Use this skill whenever the user is working with the Mechanic CLI, a Mechanic task repo,
  task sync, task preview, task publish, API tokens,
  bundled/unbundled task helper directories, or commands like mechanic init, mechanic doctor,
  mechanic tasks pull, mechanic tasks status, mechanic tasks preview, mechanic tasks diff,
  mechanic tasks publish, mechanic tasks bundle, mechanic tasks unbundle, or mechanic github init.
  This skill is for safely using the Mechanic CLI with task repos. For writing or debugging
  the Liquid task logic itself, use the mechanic-task-writer skill first, then return to this
  skill to preview, diff, and publish.
---

# Mechanic CLI

You are operating a Mechanic CLI task repo. Your job is to keep local task files, helper
directories, Git history, and the remote Mechanic shop in sync without surprising the user.

Use user-facing language around `publish`, not `push`, unless you are referring to Git.

## Default Workflow

First check whether the repo is initialized.

If `mechanic.json` is missing:

```bash
mechanic init --shop <shop.myshopify.com>
mechanic tasks pull
mechanic tasks status
```

The user needs a Mechanic API token before authenticated commands can pull,
preview remote tasks, or publish. They create it in Mechanic Settings -> API
tokens. Paste it during `mechanic init`, or run `mechanic auth login` after
init. Never print the token, commit it, or store it in repo files.

If `mechanic.json` exists, start by understanding the repo state:

```bash
mechanic doctor
mechanic tasks status
```

After editing one task:

```bash
mechanic tasks status <file>
mechanic tasks preview <file-or-helper-dir>
mechanic tasks diff <file>
mechanic tasks publish <file> --dry-run
mechanic tasks publish <file>
```

Only run the final publish command when the user has explicitly asked to publish or has
confirmed after seeing preview/diff/dry-run output.

## Editing Task Files

Mechanic CLI repos use canonical JSON files under `tasks/`. A task may also be unbundled into
a helper directory for editing long fields:

```bash
mechanic tasks unbundle tasks/example-task.json
mechanic tasks bundle tasks/example-task
```

When a helper directory exists and has changed, bundle it before previewing or publishing the
canonical JSON file. If the CLI says the helper is stale, do exactly what it says and bundle
the helper directory.

When a task has `subscriptions_template`, treat `subscriptions` as generated state. Edit the
template/helper file, not the rendered `subscriptions` array.

## Preview

Preview is the confidence check before publish:

```bash
mechanic tasks preview tasks/example-task.json
mechanic tasks preview tasks/example-task
```

Use `--remote` to preview the task currently saved in Mechanic:

```bash
mechanic tasks preview tasks/example-task.json --remote
```

Use `--json` when another agent, script, or CI job needs structured output:

```bash
mechanic tasks preview tasks/example-task.json --json
```

Preview reports sample event results, action failures, validation errors, and Shopify
permissions detected by the previewed code paths. Missing Shopify permissions cannot be
approved through the API; they are approved in Mechanic after the task is published or enabled.

## Safety Rules

- Never run `mechanic tasks publish --all` unless the user explicitly asks to publish every task.
- Prefer one-file commands while users are learning or testing.
- Do not publish when `mechanic tasks status` says a helper needs bundling.
- Do not ignore token/shop mismatch errors; they mean the API token belongs to another shop.
- Treat `mechanic tasks diff` differences as information, not a failure. Use `--exit-code` only when CI or the user explicitly wants differences to fail.
- New tasks created by publish are disabled; tell the user to review and enable them in Mechanic.
- Do not expose or log API tokens.

## GitHub Sync

GitHub Actions are optional automation, not the first workflow users need to understand.

Use this only when the user asks for GitHub sync, PR validation, pull-back PRs, or deploy
from GitHub:

```bash
mechanic github init
```

The generated workflows are for one shop. Users configure `MECHANIC_API_TOKEN` as a GitHub
secret. Keep the mental model simple:

- PR validation checks task files.
- Manual deploy previews/dry-runs first, then publishes when requested.
- Sync-from-app is manual by default and pulls Mechanic changes into a PR instead of committing directly to `main`.

## Hand Off To Task Writing

If the user asks to design, write, or debug the Liquid automation logic itself, use the
`mechanic-task-writer` skill for that work. After the task file or helper directory is edited,
return to this workflow for bundle, preview, diff, dry-run, and publish.
