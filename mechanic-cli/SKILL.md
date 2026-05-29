---
name: mechanic-cli
description: >
  Use this skill whenever the user is working with the Mechanic CLI, a Mechanic task repo,
  local task development, task sync, task preview, task publish, API tokens,
  bundled/unbundled task helper directories, or commands like mechanic init, mechanic doctor,
  mechanic shop status, mechanic tasks list, mechanic tasks open, mechanic tasks pull,
  mechanic tasks status, mechanic tasks preview, mechanic tasks diff, mechanic tasks publish,
  mechanic tasks bundle, mechanic tasks unbundle, or mechanic github init.
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
mechanic shop status
```

After editing one task:

```bash
mechanic tasks status <file>
mechanic tasks preview <task>
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

Most task commands accept a task selector. Prefer the shortest clear selector for conversation,
but use the full file path when there is ambiguity. A selector can be a JSON file, a helper
directory, a unique local slug, or a linked remote task ID:

```bash
mechanic tasks preview tasks/example-task.json
mechanic tasks preview tasks/example-task
mechanic tasks preview example-task
mechanic tasks preview <remote-task-id>
```

When a helper directory exists and has changed, bundle it before previewing or publishing the
canonical JSON file. If the CLI says the helper is stale, do exactly what it says and bundle
the helper directory.

When a task has `subscriptions_template`, treat `subscriptions` as generated state. Edit the
template/helper file, not the rendered `subscriptions` array.

Use `mechanic tasks list --verbose` when you need to see remote IDs, linked local files, and
hashes. Use `mechanic tasks open <task>` when the user wants to jump from a local file, helper
directory, slug, or remote ID to the task in the Mechanic app.

## Preview

Preview is the confidence check before publish:

```bash
mechanic tasks preview tasks/example-task.json
mechanic tasks preview tasks/example-task
```

Use `--verbose` when the user needs terminal-readable event, task run, and action run details:

```bash
mechanic tasks preview tasks/example-task.json --verbose
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

Preview may use real shop event samples selected by Mechanic. Do not paste verbose or JSON
preview output into public places without checking for shop data first.

## Shop Status

Use `mechanic shop status` as a quick operational check for the configured shop. It reports
running runs, waiting runs, queue lag, and top backlog groups. This is useful before publishing
a risky task, debugging a shop that feels slow, or answering "is Mechanic backed up for this
shop?".

Use `mechanic shop status --json` for agents, dashboards, or scripts.

## Safety Rules

- Never run `mechanic tasks publish --all` unless the user explicitly asks to publish every task.
- Prefer one-file commands while users are learning or testing.
- Remember that `mechanic tasks pull` without an argument pulls every remote task. Use
  `mechanic tasks pull <task>` when the user only wants one task.
- Do not publish when `mechanic tasks status` says a helper needs bundling.
- Do not ignore token/shop mismatch errors; they mean the API token belongs to another shop.
- Treat `mechanic tasks diff` differences as information, not a failure. Use `--exit-code` only when CI or the user explicitly wants differences to fail.
- New tasks created by publish are disabled; tell the user to review and enable them in Mechanic.
- Publishing local task JSON does not enable or disable existing tasks.
- Do not expose or log API tokens.
- For custom API hosts, only use `MECHANIC_TRUST_API_BASE_URL=1` when the user is intentionally
  testing against a Mechanic API host they control. Do not set it globally in examples.

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
- Manual deploy always dry-runs first, then publishes only when `mode=deploy`.
- Sync-from-app is manual by default and pulls Mechanic changes into a PR instead of committing directly to `main`.
- After deploy, the workflow opens or updates a sync-state PR so `.mechanic/links.json` and
  task hashes stay current.
- Sync-from-app is update-only in V1; it does not prune local files for tasks deleted in Mechanic.

Do not introduce GitHub Actions into the basic path unless the user asks for Git sync,
deployment from GitHub, or automated pull-back PRs.

## Hand Off To Task Writing

If the user asks to design, write, or debug the Liquid automation logic itself, use the
`mechanic-task-writer` skill for that work. After the task file or helper directory is edited,
return to this workflow for bundle, preview, diff, dry-run, and publish.
