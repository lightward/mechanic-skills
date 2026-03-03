# Mechanic Skills

Agent skills for [Mechanic](https://mechanic.dev), the Liquid-based automation platform for Shopify, built by [Lightward](https://lightward.com).

These skills work with any coding agent that supports the [Agent Skills](https://skills.sh) standard, including Claude Code, OpenAI Codex, Gemini CLI, Cursor, GitHub Copilot, and others.

## Available Skills

| Skill | Description |
|-------|-------------|
| [mechanic-task-writer](./mechanic-task-writer/) | Write, edit, debug, and optimize Mechanic tasks with production-ready patterns, GraphQL queries, and bulk operations |

## Installation

Install all skills:

```bash
npx skills add lightward/mechanic-skills
```

Install a specific skill:

```bash
npx skills add lightward/mechanic-skills --skill mechanic-task-writer
```

Or manually copy the skill folder to your agent's skills directory:

| Agent | Location |
|-------|----------|
| Claude Code | `~/.claude/skills/` |
| Codex | `~/.codex/skills/` |
| Gemini CLI | `~/.gemini/skills/` or `~/.agents/skills/` |
| Cursor | `.cursor/skills/` (project) or `~/.cursor/skills/` (global) |

## What is Mechanic?

Mechanic is an automation platform for Shopify stores. It uses Liquid templates, GraphQL queries, and event subscriptions to automate tasks like tagging orders, sending emails, managing inventory, and syncing data. Learn more at [learn.mechanic.dev](https://learn.mechanic.dev).

## MCP Server

Mechanic has a public MCP server that provides access to the task library and documentation. If your agent supports MCP, you can connect it for enhanced task search and doc lookups. See [learn.mechanic.dev/resources/mcp](https://learn.mechanic.dev/resources/mcp) for setup instructions.

## Resources

- [Mechanic](https://mechanic.dev/) — install from the [Shopify App Store](https://apps.shopify.com/mechanic)
- [Mechanic Task Library](https://tasks.mechanic.dev) — 359+ production-ready tasks
- [Mechanic Documentation](https://learn.mechanic.dev)
- [Mechanic Tasks GitHub](https://github.com/lightward/mechanic-tasks)
- [Shopify GraphQL API](https://shopify.dev/docs/api/admin-graphql)
- [Shopify Dev MCP](https://shopify.dev/docs/apps/build/devmcp)

## License

MIT
