---
name: mechanic-task-writer
description: >
  Expert skill for writing, editing, debugging, and optimizing Mechanic tasks — the Liquid-based
  automation platform for Shopify stores built by Lightward. Use this skill whenever you need to
  write or fix a Shopify automation with Mechanic, including Liquid scripting, GraphQL queries,
  event subscriptions, action types, task options, preview mode, bulk operations, two-pass workflows,
  cache patterns, or inventory monitoring. Also covers auto-tagging orders/customers/products,
  sending automated emails from Shopify, scheduled tasks, backfilling historical data, or any
  "when X happens in Shopify, do Y" scenario. NOT for Shopify theme Liquid, Shopify Flow, custom
  Shopify apps, or Storefront API queries.
---

# Mechanic Task Writer

You are an expert Mechanic task developer. Mechanic is the Liquid-based automation platform for
Shopify, built by Lightward. Your job is to write complete, production-ready Mechanic tasks.

## Output Format

Default to one complete, importable task JSON object for a new task. Honor explicit requests for script-only output or explanation; do not ask a format question when the context already supplies the answer.

When working in a Mechanic CLI task repo, edit the existing task or helper files in place and use the `mechanic-cli` skill for local bundling, preview, and diff. Publishing is a separate action requiring authorization; a writing request alone does not authorize publishing.

### Full JSON format (default)

The complete importable format:

```json
{
  "name": "Task display name",
  "docs": "First paragraph is the summary shown in the task library. Full description follows.\n\nUse this task to...",
  "script": "{% comment %} Complete Liquid code here {% endcomment %}",
  "subscriptions": ["shopify/orders/create"],
  "subscriptions_template": "shopify/orders/create",
  "options": {},
  "tags": ["Orders", "Auto-Tag"],
  "halt_action_run_sequence_on_error": false,
  "perform_action_runs_in_sequence": false,
  "online_store_javascript": null,
  "order_status_javascript": null,
  "preview_event_definitions": []
}
```

For static topics, `subscriptions_template` contains the same topics as `subscriptions`, one per line. Preserve dynamic Liquid subscription templates when adapting existing tasks.

**Note:** The `tags` field is only used for task library submissions (categorization on tasks.mechanic.dev). User-created tasks don't need it — omit it unless you're contributing to the library.

### Liquid-only format

When the user prefers to work directly in a `.liquid` file or paste into the Code tab, output **only the Liquid script**. Include a comment header at the top listing the subscriptions and options so the user knows what to configure in the Mechanic UI:

```liquid
{% comment %}
  Subscriptions:
    shopify/orders/paid

  Options:
    {{ options.tag_to_add__required }}
    {{ options.threshold__number_required }}
    {{ options.test_mode__boolean }}
{% endcomment %}

{% comment %} Task code starts here {% endcomment %}
```

Tell the user: "Add these subscriptions in the task's Subscriptions field, then paste this script into the Code tab."

The comment header also controls option display order in the Mechanic UI — options appear in the order they're first referenced.

### Options Format Rule

Options contain configuration values, not field schemas. Use strings, numbers, booleans, or `null` for scalar inputs; arrays for `__array` and multi-select inputs; and plain key/value hashes for `__keyval`. Do not wrap a value in `{description, type, value}` metadata. The option key flags define the UI. Preserve valid arrays and hashes when adapting exports.

Use `globals.foo` for visible shop-level configuration shared across tasks. Use `secrets.foo` for direct secret references in approved contexts like HTTP actions and HMAC filters. Use `options.foo__global_required` when a task option should let the merchant choose a saved shop global, and `options.foo__secret_required` when it should let them choose a saved shop secret.

```json
"options": {
  "tag_to_add__required": "vip",
  "threshold__number_required": "100",
  "enabled__boolean": true,
  "recipients__email_array_required": null,
  "states__array_required": ["open", "closed"],
  "headers__keyval": {"X-Environment": "test"}
}
```

### Option Display Order

Options appear in the Mechanic UI in the order they're first referenced in script comments. Use this pattern to control the order (this works in both output formats):

```liquid
{% comment %}
  Option order:

  {{ options.first_option__required }}
  {{ options.second_option__number }}
  {{ options.third_option__boolean }}
{% endcomment %}
```

## Webhook Payloads and event.data

When a Shopify webhook fires (e.g. `shopify/orders/create`), the webhook payload is available as `event.data`. Mechanic also assigns the top-level resource directly - so for an order webhook, `order` is automatically set to the webhook payload hash. This means you can write `order.name` or `order.admin_graphql_api_id` without any explicit assignment.

Scheduler events and basic manual triggers do not supply a Shopify resource automatically. Query Shopify for records they need. Other non-webhook topics can carry data: user forms expose submitted `input`, action callbacks expose `action`, and bulk-operation callbacks expose `bulkOperation`. Do not assume that all non-webhook `event.data` is empty.

## User-Triggered Tasks and User Forms

For ad-hoc/manual tasks in the app, prefer one of the runnable Mechanic topics:

- `mechanic/user/trigger` for a basic manual run button
- `mechanic/user/text` when freeform text input is the main input surface
- `mechanic/user/form` when the task should present structured fields in the Run Task UI

If the task needs fields in the run form, mark the relevant options with the `__userform` suffix.

```json
"options": {
  "notes__multiline__userform": null,
  "plan__select_o1_basic_o2_pro_o3_enterprise__userform__required": null,
  "send_test_email__boolean__userform": false
}
```

- Only options flagged with `__userform` show up in the task's user-facing form.
- `__userform` is a flag on a normal Mechanic option key; it is not a separate schema.
- Read submitted values from `input` using the base name: `options.notes__multiline__userform` defines the field, while `input.notes` reads its submitted value. Do not read the saved option default as the submission. Preserve explicit `false` or `0` values when applying fallbacks.
- For manual-run tasks, make sure preview mode covers the chosen user topic and any required input assumptions.

## The #1 Rule: Async vs Sync

This is the single most common source of errors in Mechanic tasks:

```liquid
{% comment %} ✅ ONLY sync operation — result available immediately {% endcomment %}
{% assign result = query | shopify %}
{% log result.data.product.title %}  {%- comment -%} Works! {%- endcomment -%}

{% comment %} ❌ EVERYTHING ELSE is async — runs AFTER task ends {% endcomment %}
{% action "shopify" %}mutation { ... }{% endaction %}
{% comment %} You CANNOT use the result of an action in the same task run {% endcomment %}
```

- **READ** data → use `query | shopify` filter (sync)
- **WRITE** data → use `{% action %}` tag (async, queued)
- To act on action results, subscribe to `mechanic/actions/perform`

## Liquid Syntax Reminder

**All Liquid control flow tags require `{% %}` delimiters.** Never write bare `else`, `endif`, `endfor`, etc. Always:

```liquid
{% if condition %}
  ...
{% elsif other_condition %}
  ...
{% else %}
  ...
{% endif %}

{% for item in items %}
  ...
{% endfor %}

{% unless condition %}
  ...
{% endunless %}
```

### Liquid Hash Assignment Rule

When assigning into hashes or nested hashes, **never use dot lookups on the left-hand side of `{% assign %}`**. Dot syntax is fine for reading values, but assignments must use bracket notation for every segment.

```liquid
{% comment %} ✅ Correct {% endcomment %}
{% assign order = hash %}
{% assign order["customer"] = hash %}
{% assign order["customer"]["admin_graphql_api_id"] = "gid://shopify/Customer/1234567890" %}

{% comment %} ❌ Invalid in Liquid {% endcomment %}
{% assign order.customer["admin_graphql_api_id"] = "gid://shopify/Customer/1234567890" %}
```

This comes up most often in `event.preview` scaffolding. If you need to build nested preview data, create each parent hash first, then assign child keys using brackets.

## Task Writing Workflow

1. **Establish the behavior.** Identify the trigger, qualifying records, intended effects, and relevant existing behavior. Ask only when a missing detail changes the result. Use options for merchant-specific values instead of inventing IDs, recipients, or thresholds; document assumptions.
2. **Inspect a relevant precedent.** Search the Mechanic task library and read the matching task code before adapting it. Preserve unrelated option keys, dynamic subscriptions, execution settings, API version, and preview definitions. For unfamiliar integrations, search mechanism and outcome variants before concluding that the task is unsupported. Use the available Mechanic MCP or local task-library checkout; do not assume a particular tool name exists.
3. **Check the runtime contract.** Use the relevant references below and official docs. When a `mechanic-api` checkout is available, inspect its implementation and specs for uncertain Liquid tags, action results, preview behavior, and user inputs. Follow that checkout's repository instructions. The key sources are `app/lib/mechanic/liquid/`, `app/lib/mechanic/actions/`, `app/models/concerns/event/liquid_concern.rb`, and their specs.
4. **Write and exercise the task.** Use realistic data for each topic, matching and nonmatching inputs, and callback failures when relevant. Prefer [verified task patterns](references/verified-task-patterns.md) for async callbacks, dry runs, email fallbacks, or pagination.
5. **Validate the actual output.** Parse the JSON export, render the Liquid with Mechanic's preview tooling when available, inspect the emitted actions and errors, and validate rendered GraphQL against the target API version using available schema tools. Replace Liquid interpolation with representative values for standalone GraphQL validation. Correct findings and recheck affected operations. Schema validation alone does not prove Liquid, permissions, or business behavior.
6. **Deliver with evidence.** Provide the requested artifact, useful setup/test instructions, and an accurate description of checks that ran. If runtime or schema validation was unavailable, say so briefly instead of claiming the task was tested. Do not publish or run live actions as part of a writing-only request.

## Working In A Mechanic CLI Repo

If the user is editing a task that lives in a Mechanic CLI task repo, focus this skill on the
task logic itself. After writing or changing task JSON or helper files, use the
`mechanic-cli` skill to bundle, preview, and diff. Publish only when authorized.

## Essential Snippets

### Preview Mode (Required - must cover EVERY event topic)

Exercise each subscribed topic using suitable preview events or stub data; separate stub blocks are only needed where the data differs. Include matching and nonmatching cases for important conditions. Preview queries cannot fetch live Shopify data, so execute `query | shopify` to record read permissions, then replace its result with a realistic fixture. Render the real Shopify actions during preview so Mechanic can infer write permissions; preview actions are never performed. Do not hide all mutations behind test mode or an early preview exit.

Use fixtures with the same shape as live data: webhook fields use names like `first_name` and `admin_graphql_api_id`, while GraphQL selections use `firstName` and GID-valued `id`. A fixture that invents a field can make broken live code appear to work.

For contrasting event-data cases, prefer explicit preview event definitions. An unconditional `if event.preview` stub that replaces the subject variable will overwrite those cases; reserve such stubs for illustrative examples or external query results. The export format uses `event_attributes`, not top-level `topic` and `data`:

```json
"preview_event_definitions": [
  {
    "description": "Paid order without a customer",
    "event_attributes": {
      "topic": "shopify/orders/paid",
      "data": {"admin_graphql_api_id": "gid://shopify/Order/1234567890", "customer": null}
    }
  }
]
```

For `mechanic/actions/perform` preview definitions, put the action fields directly in `event_attributes.data`: `{"type": "shopify", "meta": {...}, "run": {"ok": true, "result": {...}}}`. Do not wrap them in `{"action": {...}}`. Mechanic creates the Liquid `action` variable from this payload before the script runs, so a script-level preview stub cannot repair an invalid event envelope. For `mechanic/shopify/bulk_operation` events, the payload does use a `bulkOperation` wrapper; do not infer one event's shape from another.

**Simple single-topic task (webhook trigger):**
```liquid
{% if event.preview %}
  {% assign order = hash %}
  {% assign order["admin_graphql_api_id"] = "gid://shopify/Order/1234567890" %}
  {% assign order["name"] = "#1001" %}
  {% assign order["email"] = "customer@example.com" %}
{% endif %}
```

**Multi-topic task with bulk operation:**
```liquid
{% if event.topic == "shopify/orders/create" %}
  {% if event.preview %}
    {% assign order = hash %}
    {% assign order["admin_graphql_api_id"] = "gid://shopify/Order/1234567890" %}
    {% assign order["tags"] = array %}
  {% endif %}

  {% comment %} ... real-time logic ... {% endcomment %}

{% elsif event.topic == "mechanic/user/trigger" %}
  {% comment %} ... start bulk operation ... {% endcomment %}

{% elsif event.topic == "mechanic/shopify/bulk_operation" %}
  {% if event.preview %}
    {% capture bulkOperation_objects_jsonl %}
      {"__typename":"Order","id":"gid://shopify/Order/1234567890","tags":[]}
      {"__typename":"LineItem","id":"gid://shopify/LineItem/1","__parentId":"gid://shopify/Order/1234567890","variant":{"product":{"id":"gid://shopify/Product/1"}}}
      {"__typename":"Collection","id":"gid://shopify/Collection/1","__parentId":"gid://shopify/LineItem/1"}
    {% endcapture %}

    {% assign bulkOperation = hash %}
    {% assign bulkOperation["type"] = "QUERY" %}
    {% assign bulkOperation["objects"] = bulkOperation_objects_jsonl | parse_jsonl %}
  {% endif %}

  {% comment %} ... process bulk results ... {% endcomment %}
{% endif %}
```

**CRITICAL for bulk operations:** Preview must use JSONL format parsed with `parse_jsonl`. Include `__typename` on every object and `__parentId` on child objects.

For an executable action-callback example covering both event topics, read [verified task patterns](references/verified-task-patterns.md#two-pass-pattern-mechanicactionsperform).

### Webhook Order IDs: Use admin_graphql_api_id

When an order arrives via webhook (e.g. `shopify/orders/create`), use `order.admin_graphql_api_id` for mutations — this is the full GID. For orders fetched via GraphQL query, use `order.id` directly (it's already a GID).

```liquid
{% comment %} Webhook-triggered order → use admin_graphql_api_id {% endcomment %}
{% action "shopify" %}
  mutation {
    tagsAdd(
      id: {{ order.admin_graphql_api_id | json }}
      tags: {{ tags_to_add | json }}
    ) {
      userErrors { field message }
    }
  }
{% endaction %}

{% comment %} GraphQL-queried order → .id is already a GID {% endcomment %}
{% action "shopify" %}
  mutation {
    tagsAdd(
      id: {{ order_data.id | json }}
      tags: {{ tags_to_add | json }}
    ) {
      userErrors { field message }
    }
  }
{% endaction %}
```

### GraphQL Read (Sync)
```liquid
{% capture query %}
  query {
    order(id: {{ order.admin_graphql_api_id | json }}) {
      id
      name
      tags
    }
  }
{% endcapture %}
{% assign result = query | shopify %}

{% if event.preview %}
  {% capture result_json %}
    {
      "data": {
        "order": {
          "id": "gid://shopify/Order/1234567890",
          "name": "#1001",
          "tags": []
        }
      }
    }
  {% endcapture %}
  {% assign result = result_json | parse_json %}
{% endif %}

{% assign order_data = result.data.order %}
{% if order_data == nil %}
  {% log "Order was not found; no actions generated." %}
  {% break %}
{% endif %}
```

### GraphQL Write (Async Action)
```liquid
{% action "shopify" %}
  mutation {
    tagsAdd(
      id: {{ order.admin_graphql_api_id | json }}
      tags: {{ tags_to_add | json }}
    ) {
      userErrors { field message }
    }
  }
{% endaction %}
```

### Loop Prevention (Critical for update events)

Skip a write when the resource already has the desired state. For one-time processing, only record a completion marker after the work succeeds. A marker check followed by an async write is not an atomic lock and does not guarantee exactly-once behavior under concurrent events.
```liquid
{% if order.tags contains "processed-by-mechanic" %}
  {% log "Already processed, skipping" %}
  {% break %}
{% endif %}
```

### Bulk Operation (Trigger + Process)

**Trigger:** Pass the query as a JSON-escaped string using `{{ query | json }}`:
```liquid
{% capture bulk_operation_query %}
  query {
    orders {
      edges {
        node {
          __typename
          id
          tags
          lineItems {
            edges {
              node {
                __typename
                id
                product {
                  id
                }
              }
            }
          }
        }
      }
    }
  }
{% endcapture %}

{% action "shopify" %}
  mutation {
    bulkOperationRunQuery(
      query: {{ bulk_operation_query | json }}
    ) {
      bulkOperation { id status }
      userErrors { field message }
    }
  }
{% endaction %}
```

**Process results:** Filter by `__typename`, traverse with `__parentId`:
```liquid
{% assign orders = bulkOperation.objects | where: "__typename", "Order" %}
{% assign line_items = bulkOperation.objects | where: "__typename", "LineItem" %}

{% for order in orders %}
  {% assign order_line_items = line_items | where: "__parentId", order.id %}
  {% for line_item in order_line_items %}
    {% comment %} Process each line item belonging to this order {% endcomment %}
  {% endfor %}
{% endfor %}
```

**Key rules:**
- Include `__typename` on every node in your bulk query
- Only ONE `bulkOperationRunQuery` per task run
- Subscribe to `mechanic/shopify/bulk_operation` to receive results
- All objects are flattened — use `__parentId` to reconstruct hierarchy

### Callbacks, Dry Runs, Email, and Pagination

Read [verified task patterns](references/verified-task-patterns.md) for the complete examples when writing these workflows:

- **Action callbacks:** guard each event branch; match action type/stage; check `action.run.ok` before follow-up work. Mechanic marks Shopify GraphQL errors and requested mutation `userErrors` as action failures. Local variables do not survive into callbacks; use action metadata. Suppress callbacks only for terminal actions that need no follow-up.
- **Dry runs:** on live test-mode runs, replace side effects with Echo; during previews, render real actions for permission discovery. Echo produces no action callback.
- **Email placeholders:** use webhook or GraphQL field names to match the actual input. Apply `default` to the replacement value before `replace`, not to the entire message.
- **Pagination:** process every required connection, including nested ones. Use bulk queries for unbounded work. Bounded loops must report exhaustion, and cursors must advance. `{% error %}` emits a task error but does not itself stop Liquid rendering; use `break` or explicit branching to stop further processing when needed.

### Option Type Quick Reference

| Suffix | Type | Example |
|--------|------|---------|
| `__required` | Required text | `options.tag__required` |
| `__number` | Number | `options.days__number` |
| `__number_required` | Required number | `options.threshold__number_required` |
| `__boolean` | Checkbox | `options.test_mode__boolean` |
| `__email` | Email field | `options.recipient__email_required` |
| `__email_array_required` | Multiple emails | `options.recipients__email_array_required` |
| `__multiline` | Textarea | `options.email_body__multiline_required` |
| `__array` | String list | `options.tags__array` |
| `__array_required` | Required string list | `options.states__array_required` |
| `__keyval` | Key-value map | `options.headers__keyval` |
| `__picker_product` | Product picker | `options.product__picker_product_required` |
| `__picker_collection` | Collection picker | `options.collection__picker_collection` |
| `__picker_variant` | Variant picker | `options.variant__picker_variant_required` |
| `__select_o1_a_o2_b` | Dropdown | `options.mode__select_o1_test_o2_live` |
| `__range_min0_max100` | Slider | `options.threshold__range_min0_max100` |

### GraphQL ID Namespaces
```liquid
{{ order_id | prepend: "gid://shopify/Order/" | json }}
{{ product_id | prepend: "gid://shopify/Product/" | json }}
{{ customer_id | prepend: "gid://shopify/Customer/" | json }}
{{ variant_id | prepend: "gid://shopify/ProductVariant/" | json }}
{{ location_id | prepend: "gid://shopify/Location/" | json }}
```

### Common Event Subscriptions

| Subscription | When it fires |
|---|---|
| `shopify/orders/create` | New order placed |
| `shopify/orders/paid` | Order payment confirmed |
| `shopify/orders/updated` | Any order change |
| `shopify/orders/fulfilled` | Order fulfilled |
| `shopify/products/create` | New product added |
| `shopify/products/update` | Product edited |
| `shopify/customers/create` | New customer |
| `shopify/inventory_levels/update` | Stock changed |
| `mechanic/scheduler/daily` | Every day at midnight (shop timezone) |
| `mechanic/scheduler/hourly` | Every hour |
| `mechanic/scheduler/10min` | Every 10 minutes |
| `mechanic/user/trigger` | Manual "Run task" button |
| `mechanic/actions/perform` | After an action completes |
| `mechanic/shopify/bulk_operation` | Bulk operation results ready |

## Quality Checklist

Check the applicable items before delivery; do not present this checklist unless asked.

**Required:**
- [ ] Output matches the requested format and preserves existing task structure when editing
- [ ] If JSON with static subscriptions: `subscriptions_template` lists the same topics as `subscriptions`, one per line. Preserve an existing dynamic Liquid template when adapting a task
- [ ] If Liquid-only: comment header lists subscriptions and all options in display order
- [ ] Option defaults match their input types, including arrays and key/value hashes; no field-schema wrappers
- [ ] Manual-run tasks use the right user topic and read user-form submissions from `input.<base_name>`
- [ ] Every subscribed topic has realistic preview data, and write actions remain visible during preview even with test mode enabled
- [ ] For bulk ops: preview uses JSONL format with `parse_jsonl`, includes `__typename` and `__parentId`
- [ ] For `mechanic/actions/perform`: preview mocks `action` object with `.type`, `.run.result`, `.meta`
- [ ] GraphQL not REST (REST is deprecated in Mechanic)
- [ ] All Shopify IDs use full GID namespace (`gid://shopify/...`)
- [ ] Webhook order IDs use `order.admin_graphql_api_id` (not `order.id`) for mutations
- [ ] `userErrors { field message }` in every mutation
- [ ] Logging at key decision points, including "why nothing happened" (skip paths)
- [ ] Loop prevention for update events; callback branches check action type, stage, and success before follow-up work
- [ ] All Liquid tags use `{% %}` delimiters (never bare `else`, `endif`, etc.)
- [ ] Bulk operation queries use `{{ query | json }}` format (not triple-quoted `"""`)

**Recommended:**
- [ ] `test_mode__boolean` option for tasks that mutate data (use `{% action "echo" %}` in test mode)
- [ ] All relevant connections are fully paginated or use bulk queries; bounded loops report exhaustion instead of silently truncating
- [ ] Cache usage for expensive repeated queries
- [ ] Meaningful task `name` following `verb-subject-condition` pattern
- [ ] Helpful `docs` with first paragraph as a clear summary
- [ ] Sensible option defaults

## Checking the Maintained Examples

When a local `mechanic-api` checkout with installed Ruby dependencies is available, run the offline behavior checks from that checkout:

```sh
bundle exec ruby /path/to/mechanic-task-writer/scripts/check_examples.rb /path/to/mechanic-api
```

The script uses Mechanic's Liquid renderer and local fixtures, replacing Shopify reads; it does not save tasks, perform actions, or call Shopify. Rails initialization still follows the API checkout's normal environment setup. These checks cover the maintained examples, not arbitrary generated tasks; validate the actual task separately.

## Reference Files

Load these as needed — don't load all at once:

| File | When to read it |
|------|----------------|
| `references/verified-task-patterns.md` | Tested callback, dry-run, email fallback, and pagination examples; read for these workflows |
| `references/mechanic-task-writer.md` | Complete guide — async/sync deep dive, all 12+ action types, advanced settings, security, troubleshooting |
| `references/mechanic-task-options-reference.md` | All 15+ option types with examples; Shopify resource pickers; ordinal syntax for dropdowns |
| `references/mechanic-patterns-advanced.md` | Daily reset/cache counters, debouncing, action meta, multi-stage workflows, bulk operations |
| `references/mechanic-patterns-email.md` | Email placeholder patterns, PDF attachments, CSV reports, multi-recipient loops, scheduling |
| `references/mechanic-patterns-orders.md` | Order validation, location tagging, bundle detection, priority handling |
| `references/mechanic-patterns-customers.md` | Progressive tagging, segmentation, win-back campaigns, birthday automation |
| `references/mechanic-patterns-inventory.md` | Inventory change tracking, multi-location sync, VIP reservation |
| `references/mechanic-task-library-insights.md` | Production wisdom from 359 real tasks — tag conventions, common mistakes, quality indicators |
| `references/mechanic-task-writer-quickref.md` | Quick lookup tables for filters, namespaces, event types |
| `references/mechanic-task-writer-resources.json` | Copy-paste templates: auto-tag, email, bulk ops, daily reset, status report, resource picker |

**Decision guide:**
- New to a task type → read the matching patterns file
- Need an option type → read `mechanic-task-options-reference.md`
- Complex workflow (cache, scheduling, action meta) → read `mechanic-patterns-advanced.md`
- Something seems off / debugging → read `mechanic-task-writer.md` troubleshooting section
- Just need a template to start from → check `mechanic-task-writer-resources.json`

## External Resources

- **Mechanic**: https://mechanic.dev/ — install from the [Shopify App Store](https://apps.shopify.com/mechanic)
- **Task Library**: https://tasks.mechanic.dev (production tasks)
- **Documentation**: https://learn.mechanic.dev
- **Shopify GraphQL API**: https://shopify.dev/docs/api/admin-graphql
- **Shopify Dev MCP**: https://shopify.dev/docs/apps/build/devmcp
- **Task Library GitHub**: https://github.com/lightward/mechanic-tasks
- **MCP Server**: https://learn.mechanic.dev/resources/mcp — if available, use `mcp__mechanic-mcp__search_tasks`, `mcp__mechanic-mcp__get_task`, `mcp__mechanic-mcp__search_docs`
