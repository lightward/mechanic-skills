# Mechanic Task Writer for Shopify Automation

Expert skill for writing Shopify automation tasks using [Mechanic](https://apps.shopify.com/mechanic) - the #1 automation platform for Shopify Plus, Advanced, and Basic stores.

**Mechanic App**: <https://apps.shopify.com/mechanic>
**Documentation**: <https://learn.mechanic.dev>
**Task Library**: <https://tasks.mechanic.dev>

This skill helps you write, modify, and optimize Mechanic tasks using Liquid scripting for Shopify store automation.

## When to Use This Skill

Use this skill when:

- Creating new Mechanic tasks from scratch
- Modifying existing tasks to add features or fix bugs
- Optimizing task performance
- Converting REST API calls to GraphQL (REST is deprecated)
- Implementing email templates with placeholder patterns
- Setting up bulk operations for large datasets
- Creating preview mode data for testing
- Adding error handling and logging
- Searching for similar existing tasks to avoid reinventing
- Learning Mechanic patterns from the 500+ task library

## Available Resources and Tools

### Recommended MCP Servers

For complete Mechanic task development, install these MCP servers:

1. **mechanic-mcp** - Search and analyze 500+ existing Mechanic tasks
2. **shopify-dev** (Highly Recommended) - Access Shopify GraphQL schemas, mutations, queries, and API documentation

These servers provide instant access to:
- Real task examples and patterns
- Complete GraphQL API documentation
- Object type definitions
- Mutation/query examples
- Best practices from production code

### MCP Servers for Task Discovery

Use the mechanic-mcp server to search existing tasks and documentation:

```bash
# Search for similar tasks before creating new ones
mcp__mechanic-mcp__search_tasks query:"auto-tag orders" tags:["Orders", "Auto-Tag"]

# Get full task details including code
mcp__mechanic-mcp__get_task id:"auto-tag-orders-when-paid"

# Find similar tasks by handle
mcp__mechanic-mcp__similar_tasks handle:"auto-tag-orders-when-paid"

# Search Mechanic documentation
mcp__mechanic-mcp__search_docs query:"email placeholders"
```

**Note**: If MCP servers are not available, you can:
- Browse tasks directly at https://tasks.mechanic.dev/
- Use the GitHub repository at https://github.com/lightward/mechanic-tasks
- Reference the local `/tasks/` directory if you have the repo cloned
- Search documentation at https://learn.mechanic.dev/

### Shopify GraphQL & Admin API Resources

For learning Shopify's GraphQL API and Admin API:

```bash
# Use the Shopify Dev MCP server (if available)
# This provides direct access to Shopify documentation and API references

# Alternative resources:
# - Shopify GraphQL Admin API docs: https://shopify.dev/docs/api/admin-graphql
# - GraphQL Explorer: https://shopify.dev/docs/apps/tools/graphiql-admin-api
# - API Reference: https://shopify.dev/docs/api
```

**Recommended**: Install the Shopify Dev MCP server for instant access to:
- GraphQL schema documentation
- Mutation and query examples
- Object type references
- API versioning information


## Task Structure Essentials

Every Mechanic task JSON export contains these fields:

### Required Fields

- `name`: Task display name
- `docs`: Documentation (first paragraph becomes summary, used in task library)
- `script`: The Liquid code that executes the automation
- `subscriptions`: Array of event topics the task responds to
- `subscriptions_template`: Newline-separated string of subscriptions (for UI)
- `options`: Hash of option configurations (auto-generated from script)
- `tags`: Array of category tags from approved enum list

### Optional/Advanced Fields

- `halt_action_run_sequence_on_error`: Boolean, default `false`. Set to `true` to stop all remaining actions if one fails
- `perform_action_runs_in_sequence`: Boolean, default `false`. Set to `true` to run actions sequentially instead of in parallel
- `preview_event_definitions`: Array of preview event configurations for testing
- `online_store_javascript`: JavaScript code for online store customization (rarely used)
- `order_status_javascript`: JavaScript for order status page (rarely used)

### Complete JSON Structure Example

```json
{
  "name": "Auto-tag orders when paid",
  "docs": "This task watches for newly-paid orders and adds a configurable tag.",
  "script": "{% action \"shopify\" %}\n  mutation { ... }\n{% endaction %}",
  "subscriptions": ["shopify/orders/paid"],
  "subscriptions_template": "shopify/orders/paid",
  "options": {
    "order_tag_to_apply__required": "paid"
  },
  "halt_action_run_sequence_on_error": false,
  "perform_action_runs_in_sequence": false,
  "preview_event_definitions": [],
  "online_store_javascript": null,
  "order_status_javascript": null
}
```

**Note**: The `tags` field is only used in the task library repository for categorization. User-created tasks don't need to include it.

## Advanced Task Settings

### Halt Action Sequence on Error

Use when action order matters and failures should stop processing:

```json
{
  "halt_action_run_sequence_on_error": true
}
```

**Use case**: If action 1 creates a metafield and action 2 updates it, stopping on error prevents action 2 from running if action 1 fails.

### Perform Actions in Sequence

Force actions to run one after another instead of in parallel:

```json
{
  "perform_action_runs_in_sequence": true
}
```

**Use case**: When actions have dependencies (e.g., creating records before updating them, ensuring GraphQL mutations complete in order).

### Preview Event Definitions

Define realistic preview scenarios for testing:

```json
{
  "preview_event_definitions": [
    {
      "description": "Order created",
      "event_attributes": {
        "topic": "shopify/orders/create",
        "data": {
          "order": {
            "admin_graphql_api_id": "gid://shopify/Order/1234567890"
          }
        }
      }
    }
  ]
}
```

**Note**: Most tasks (76%) use in-code preview mocking with `{% if event.preview %}` instead of preview event definitions.

## Action Meta and Control Parameters

### Action Meta for State Tracking

Attach metadata to actions to track workflow state:

```liquid
{% assign meta = hash %}
{% assign meta["stage"] = "initial_request" %}
{% assign meta["order_id"] = order.admin_graphql_api_id %}

{% action "http", __meta: meta %}
  {
    "method": "post",
    "url": "https://api.example.com/verify",
    "body": {{ order | json }}
  }
{% endaction %}
```

**Access meta in mechanic/actions/perform**:

```liquid
{% if event.topic == "mechanic/actions/perform" %}
  {% if action.type == "http" and action.meta.stage == "initial_request" %}
    {% log "Processing response for order", order_id: action.meta.order_id %}
    {% if action.run.ok %}
      {% comment %} Handle successful response {% endcomment %}
    {% endif %}
  {% endif %}
{% endif %}
```

### Control Parameters

#### Skip mechanic/actions/perform Event

Prevent follow-up event for specific action:

```liquid
{% action "http", method: "get", url: url, __perform_event: false %}
```

**Use case**: When you don't need to process the action result, reducing unnecessary event processing.

**Note**: In two-pass patterns where you queue an action in the first event and handle results in `mechanic/actions/perform`, use `__perform_event: false` when the action itself doesn't need result handling to avoid unnecessary extra events.

#### Inline Meta with Any Action Syntax

```liquid
{% assign meta = hash %}
{% assign meta["source"] = "cache" %}
{% action "cache", "set", "foo", "bar", __meta: meta %}
```

### Multi-Stage Workflow Example

```liquid
{% if event.topic == "shopify/orders/create" %}
  {% comment %} Stage 1: External verification {% endcomment %}
  {% assign meta = hash %}
  {% assign meta["stage"] = "verification" %}
  {% assign meta["order_id"] = order.admin_graphql_api_id %}
  {% assign meta["order_total"] = order.totalPriceSet.shopMoney.amount %}

  {% action "http", __meta: meta %}
    {
      "method": "post",
      "url": "https://fraud-check.example.com/verify",
      "body": {
        "order_id": {{ order.admin_graphql_api_id | json }},
        "total": {{ order.totalPriceSet.shopMoney.amount | json }}
      }
    }
  {% endaction %}

{% elsif event.topic == "mechanic/actions/perform" %}
  {% if action.type == "http" and action.meta.stage == "verification" %}
    {% comment %} Stage 2: Process verification result {% endcomment %}
    {% if action.run.ok %}
      {% assign verification = action.run.response.body | parse_json %}

      {% if verification.approved %}
        {% comment %} Stage 3: Tag approved order {% endcomment %}
        {% action "shopify" %}
          mutation {
            tagsAdd(
              id: {{ action.meta.order_id | json }}
              tags: ["fraud-check-passed"]
            ) {
              userErrors { field message }
            }
          }
        {% endaction %}
      {% else %}
        {% comment %} Stage 3: Alert on suspicious order {% endcomment %}
        {% action "email" %}
          {
            "to": {{ shop.email | json }},
            "subject": "Suspicious order flagged",
            "body": "Order total: ${{ action.meta.order_total }}<br>Risk score: {{ verification.risk_score }}"
          }
        {% endaction %}
      {% endif %}
    {% endif %}
  {% endif %}
{% endif %}
```

## Mechanic Code Snippets

Mechanic's Monaco editor provides built-in code snippets. Type these keywords in the editor and press Tab:

### `bulk_operation_query` Snippet

Complete template for bulk operations. Prompts for:
1. Resource name (camelCase, e.g., `productVariant`)
2. Resource typename (PascalCase, e.g., `ProductVariant`)

Expands to full bulk operation structure with query, subscription, and result processing.

### `gid` Snippet

Shopify global ID helper. Prompts for resource type and expands to:

```liquid
"gid://shopify/Product/1234567890"
```

**Use for**: Creating preview data with realistic GIDs.

### `object_query` Snippet

Single resource GraphQL query template. Prompts for resource name (camelCase) and typename (PascalCase).

Expands to:

```liquid
{% capture query %}
  query {
    product(id: {{ product_id | json }}) {
      id
      title
    }
  }
{% endcapture %}

{% assign result = query | shopify %}

{% if event.preview %}
  {% capture result_json %}
    {
      "data": {
        "product": {
          "id": "gid://shopify/Product/1234567890",
          "title": "Example Product"
        }
      }
    }
  {% endcapture %}
  {% assign result = result_json | parse_json %}
{% endif %}
```

### `paginated_query` Snippet

Cursor-based pagination template for collections:

```liquid
{% assign cursor = nil %}

{% for n in (1..100) %}
  {% capture query %}
    query {
      products(first: 250, after: {{ cursor | json }}) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          id
          title
        }
      }
    }
  {% endcapture %}

  {% assign result = query | shopify %}

  {% comment %} Process results {% endcomment %}

  {% if result.data.products.pageInfo.hasNextPage %}
    {% assign cursor = result.data.products.pageInfo.endCursor %}
  {% else %}
    {% break %}
  {% endif %}
{% endfor %}
```

**Tip**: Use these snippets as starting points and customize for your needs.

## ⚠️ CRITICAL: Mechanic is Async & Event-Driven

### The One Exception: The `shopify` Filter

**THE MOST IMPORTANT CONCEPT**: The `shopify` filter is the ONLY way to get inline results!

```liquid
{% comment %} ✅ The ONLY synchronous operation - shopify FILTER {% endcomment %}
{% capture query %}
  query { product(id: "...") { title } }
{% endcapture %}
{% assign result = query | shopify %}
{% log title: result.data.product.title %}  {% comment %} This works! Result is available immediately! {% endcomment %}
```

**EVERYTHING ELSE is async** - ALL actions (including shopify mutations) run AFTER your task completes!

```liquid
{% comment %} ❌ WRONG - This won't work! {% endcomment %}
{% action "shopify" %}
  mutation {
    productUpdate(input: {id: "...", title: "New"}) {
      product { id title }
      userErrors { field message }
    }
  }
{% endaction %}
{% comment %} You CANNOT use the result here - the action hasn't run yet! {% endcomment %}
{% log product_title: result.data.product.title %} {% comment %} This will be nil! {% endcomment %}

{% comment %} ✅ CORRECT - Handle results in mechanic/actions/perform {% endcomment %}
```

### The Execution Flow

1. **Event occurs** → Creates EventRun
2. **Tasks subscribed to event** → Create TaskRuns
3. **Task code executes** → Queues actions (doesn't run them)
4. **Task completes** → ActionRuns execute asynchronously
5. **Action results** → Trigger mechanic/actions/perform events

### Handling Action Results

To work with action results, subscribe to `mechanic/actions/perform`:

```liquid
{% if event.topic == "shopify/orders/create" %}
  {% comment %} First pass - queue the action {% endcomment %}
  {% action "shopify" %}
    mutation {
      orderUpdate(input: {id: {{ order.admin_graphql_api_id | json }}, tags: ["processed"]}) {
        order { id tags }
        userErrors { field message }
      }
    }
  {% endaction %}

{% elsif event.topic == "mechanic/actions/perform" %}
  {% comment %} Second pass - handle the result {% endcomment %}
  {% if action.type == "shopify" %}
    {% if action.run.ok %}
      {% assign updated_order = action.run.result.data.orderUpdate.order %}
      {% log message: "Order updated", tags: updated_order.tags %}

      {% comment %} Now you can trigger follow-up actions based on the result {% endcomment %}
      {% action "email" %}
        {
          "to": {{ order.email | json }},
          "subject": "Order processed",
          "body": "Your order has been tagged as processed."
        }
      {% endaction %}
    {% else %}
      {% log error: action.run.error %}
    {% endif %}
  {% endif %}
{% endif %}
```

### Event Chaining Pattern

Since everything is async, use events to chain operations:

```liquid
{% comment %} Task 1: Process order {% endcomment %}
{% if event.topic == "shopify/orders/create" %}
  {% comment %} Do initial processing {% endcomment %}
  {% action "event" %}
    {
      "topic": "user/orders/send_to_warehouse",
      "data": { "order_id": {{ order.admin_graphql_api_id | json }} }
    }
  {% endaction %}
{% endif %}

{% comment %} Task 2: Subscribe to custom event {% endcomment %}
{% if event.topic == "user/orders/send_to_warehouse" %}
  {% comment %} This runs in a completely separate task run {% endcomment %}
  {% action "http" %}
    {
      "method": "POST",
      "url": "https://warehouse.example.com/api/orders",
      "body": {{ event.data | json }}
    }
  {% endaction %}
{% endif %}
```

### Parallel vs Sequential Actions

#### Actions in same task = Parallel by default
```liquid
{% comment %} These all queue at once and run in parallel after task completes {% endcomment %}
{% action "email" %}...{% endaction %}
{% action "slack" %}...{% endaction %}
{% action "http" %}...{% endaction %}
```

#### Force sequential with task setting
```json
{
  "perform_action_runs_in_sequence": true,
  "halt_action_run_sequence_on_error": true
}
```

#### Or use event chaining for guaranteed sequence
```liquid
{% if event.topic == "shopify/orders/create" %}
  {% action "event" %}
    { "topic": "user/step1", "data": {...} }
  {% endaction %}
{% elsif event.topic == "user/step1" %}
  {% comment %} This runs after step1 completes {% endcomment %}
  {% action "event" %}
    { "topic": "user/step2", "data": {...} }
  {% endaction %}
{% elsif event.topic == "user/step2" %}
  {% comment %} This runs after step2 completes {% endcomment %}
{% endif %}
```

### Common Async Pitfalls

1. **Trying to read action results immediately** - Won't work!
2. **Assuming actions run in order** - They're parallel unless configured
3. **Not handling mechanic/actions/perform** - Missing action results
4. **Creating accidental loops** - Task triggers itself endlessly
5. **Expecting synchronous HTTP responses** - Use webhooks instead

## Core Liquid Patterns

### Critical Distinction: Sync vs Async Operations

#### Sync vs Async Operations in Mechanic

| Operation | Type | When It Runs | Can Use Result |
| --- | --- | --- | --- |
| `query \| shopify` | **SYNC** | Immediately | ✅ Yes, right away |
| `cache[key]` read | **SYNC** | Immediately | ✅ Yes, right away |
| Liquid filters | **SYNC** | Immediately | ✅ Yes, right away |
| `{% action "shopify" %}` | **ASYNC** | After task ends | ❌ No, need mechanic/actions/perform |
| `{% action "email" %}` | **ASYNC** | After task ends | ❌ No |
| `{% action "http" %}` | **ASYNC** | After task ends | ❌ No |
| `{% action "cache", "set" %}` | **ASYNC** | After task ends | ❌ No |
| ALL other actions | **ASYNC** | After task ends | ❌ No |

**Key Point**: The `shopify` filter is the ONLY way to get EXTERNAL API data synchronously! Cache reads are also sync, but actions to SET cache are async.

### Critical Distinction: Reading vs Writing Shopify Data

#### READING from Shopify = Use the `shopify` FILTER

```liquid
{% comment %} ✅ READING - Use shopify FILTER for queries {% endcomment %}
{% capture query %}
  query {
    product(id: {{ product_id | prepend: "gid://shopify/Product/" | json }}) {
      title
      variants(first: 250) {
        nodes { id sku inventoryQuantity }
      }
    }
  }
{% endcapture %}
{% assign result = query | shopify %}

{% comment %} Now you can use the result immediately {% endcomment %}
{% log product_title: result.data.product.title %}
```

#### WRITING to Shopify = Use the `shopify` ACTION

```liquid
{% comment %} ✅ WRITING - Use shopify ACTION for mutations {% endcomment %}
{% action "shopify" %}
  mutation {
    tagsAdd(id: {{ resource_id | json }}, tags: {{ tags | json }}) {
      userErrors { field message }
    }
  }
{% endaction %}

{% comment %} ⚠️ This mutation runs AFTER task completes! {% endcomment %}
{% comment %} Handle results in mechanic/actions/perform if needed {% endcomment %}
```

#### Common Pattern: Read, Process, Write

```liquid
{% comment %} Step 1: READ data using filter {% endcomment %}
{% capture query %}
  query {
    product(id: {{ product_id | json }}) {
      title
      tags
    }
  }
{% endcapture %}
{% assign result = query | shopify %}

{% comment %} Step 2: PROCESS data immediately {% endcomment %}
{% if result.data.product.tags contains "sale" %}
  {% assign new_price = original_price | times: 0.8 %}

  {% comment %} Step 3: WRITE changes using action (runs after task) {% endcomment %}
  {% action "shopify" %}
    mutation {
      productUpdate(input: {
        id: {{ product_id | json }}
        variants: [{
          id: {{ variant_id | json }}
          price: {{ new_price | json }}
        }]
      }) {
        userErrors { field message }
      }
    }
  {% endaction %}
{% endif %}
```

### Email with Placeholder Pattern

```liquid
{% comment %} Option definition {% endcomment %}
"email_subject__required": "Order Confirmation",
"email_body__multiline_required": "Hello CUSTOMER_NAME,\n\nYour order ORDER_NUMBER has been processed."

{% comment %} In script {% endcomment %}
{% assign email_subject = options.email_subject__required %}
{% assign email_body = options.email_body__multiline_required
  | replace: "CUSTOMER_NAME", customer.name
  | replace: "ORDER_NUMBER", order.name %}

{% action "email" %}
  {
    "to": {{ customer.email | json }},
    "subject": {{ email_subject | strip | json }},
    "body": {{ email_body | strip | newline_to_br | json }}
  }
{% endaction %}
```

### Preview Mode

```liquid
{% if event.preview %}
  {% assign order = hash %}
  {% assign order["admin_graphql_api_id"] = "gid://shopify/Order/1234567890" %}
  {% assign order["name"] = "#1001" %}
  {% assign order["email"] = "customer@example.com" %}
  {% assign order["tags"] = array %}
  {% assign order["tags"][0] = "vip" %}
{% endif %}
```

## Action Types Reference

### Complete List of Mechanic Actions

| Type | Purpose | Example Usage |
| --- | --- | --- |
| `shopify` | Shopify GraphQL mutations | Tags, inventory, orders |
| `email` | Transactional emails | Notifications, reports |
| `http` | External HTTP requests | Webhooks, APIs |
| `cache` | Persistent key-value storage | State, counters |
| `event` | Trigger custom events | Scheduling, chaining |
| `files` | Generate PDF, CSV, ZIP | Reports, documents |
| `echo` | Debug output | Testing, preview |
| `ftp` | File transfers | Uploads, backups |
| `slack` | Slack notifications | Alerts, updates |
| `google_sheets` | Google Sheets integration | Data export |
| `google_drive` | Google Drive integration | File storage |
| `flow` | Shopify Flow integration | Workflow triggers |

### Action Type Examples

#### Email Action
```liquid
{% action "email" %}
  {
    "to": {{ customer.email | json }},
    "subject": {{ subject | strip | json }},
    "body": {{ body | strip | newline_to_br | json }},
    "from_display_name": {{ shop.name | json }},
    "reply_to": {{ shop.customer_email | json }},
    "bcc": {{ options.bcc_emails__email_array | json }},
    "attachments": {
      "report.pdf": {
        "pdf": {
          "html": {{ html_content | json }}
        }
      }
    }
  }
{% endaction %}
```

#### HTTP Action
```liquid
{% action "http" %}
  {
    "method": "POST",
    "url": {{ webhook_url | json }},
    "headers": {
      "Content-Type": "application/json",
      "Authorization": "Bearer {{ api_key }}"
    },
    "body": {
      "order_id": {{ order.admin_graphql_api_id | json }},
      "status": "processed"
    }
  }
{% endaction %}
```

#### Cache Actions
```liquid
{% comment %} Set value {% endcomment %}
{% action "cache", "set", cache_key, value %}

{% comment %} Delete value {% endcomment %}
{% action "cache", "del", cache_key %}

{% comment %} Increment counter {% endcomment %}
{% action "cache", "incr", cache_key %}

{% comment %} Decrement counter {% endcomment %}
{% action "cache", "decr", cache_key %}
```

#### Files Action
```liquid
{% action "files" %}
  {
    "report.csv": {
      "csv": {
        "rows": {{ csv_rows | json }}
      }
    },
    "invoice.pdf": {
      "pdf": {
        "html": {{ invoice_html | json }},
        "__force_pdfcrowd": true
      }
    },
    "archive.zip": {
      "zip": {
        "files": {
          "data.json": {{ data | json }},
          "readme.txt": "Archive contents"
        }
      }
    }
  }
{% endaction %}
```

#### Event Action
```liquid
{% action "event" %}
  {
    "topic": "user/task/process",
    "data": {
      "order_id": {{ order.admin_graphql_api_id | json }},
      "customer_id": {{ customer.admin_graphql_api_id | json }}
    },
    "run_at": {{ "now" | date: "%s", advance: "1 hour" | json }},
    "task_id": {{ specific_task.id | json }}
  }
{% endaction %}
```

#### Slack Action
```liquid
{% action "slack" %}
  {
    "channel": "#orders",
    "text": "New order {{ order.name }} received!",
    "attachments": [
      {
        "color": "good",
        "fields": [
          {
            "title": "Customer",
            "value": {{ customer.email | json }},
            "short": true
          },
          {
            "title": "Total",
            "value": {{ order.total_price | currency | json }},
            "short": true
          }
        ]
      }
    ]
  }
{% endaction %}
```

#### FTP Action
```liquid
{% action "ftp" %}
  {
    "host": {{ ftp_host | json }},
    "port": 21,
    "user": {{ ftp_user | json }},
    "password": {{ ftp_password | json }},
    "uploads": {
      "/remote/path/report.csv": {
        "csv": {
          "rows": {{ rows | json }}
        }
      }
    }
  }
{% endaction %}
```

#### Flow Action
```liquid
{% action "flow" %}
  {
    "flow_trigger_id": {{ flow_trigger_id | json }},
    "resources": [
      {
        "id": {{ order.admin_graphql_api_id | json }}
      }
    ]
  }
{% endaction %}
```

## Common Task Types

### 1. Auto-Tagging Tasks

Subscribe to: `shopify/orders/create`, `shopify/customers/create`, etc.

Pattern:

```liquid
{% if condition_met %}
  {% action "shopify" %}
    mutation {
      tagsAdd(id: {{ resource.admin_graphql_api_id | json }}, tags: {{ tag | json }}) {
        userErrors { field message }
      }
    }
  {% endaction %}
{% endif %}
```

### 2. Scheduled Tasks

Subscribe to: `mechanic/scheduler/daily`, `mechanic/scheduler/10min`, etc.

Pattern:

```liquid
{% capture query %}
  query {
    products(first: 250, query: "status:active") {
      pageInfo { hasNextPage endCursor }
      nodes { id title inventoryQuantity }
    }
  }
{% endcapture %}
{% assign result = query | shopify %}
{% comment %} Process and paginate if needed {% endcomment %}
```

### 3. Email Notifications

Pattern with customizable templates:

```liquid
{% assign placeholders = hash %}
{% assign placeholders["CUSTOMER_NAME"] = customer.firstName | default: "there" %}
{% assign placeholders["ORDER_NUMBER"] = order.name %}

{% assign email_body = options.email_body__multiline_required %}
{% for placeholder in placeholders %}
  {% assign email_body = email_body | replace: placeholder[0], placeholder[1] %}
{% endfor %}
```

### 4. Bulk Operations

For processing large datasets:

```liquid
{% capture bulk_query %}
  { products { edges { node { id title } } } }
{% endcapture %}

{% action "shopify" %}
  mutation {
    bulkOperationRunQuery(
      query: {{ bulk_query | json }}
    ) {
      bulkOperation { id status }
      userErrors { field message }
    }
  }
{% endaction %}
```

Then handle results in `mechanic/shopify/bulk_operation` subscription.

### 5. Event Chaining

```liquid
{% action "event" %}
  {
    "topic": "user/orders/followup",
    "data": { "order_id": {{ order.admin_graphql_api_id | json }} },
    "run_at": {{ "now" | date: "%s", advance: "30 days" | json }}
  }
{% endaction %}
```

## Option Configuration

**⭐ See `mechanic-task-options-reference.md` for complete option system documentation.**

### Quick Reference

Options are auto-created when referenced in task code. Use flags (tokens after `__`) to control type and behavior:

**⚠️ Important**: Option default values MUST be plain values (null, string, number, boolean). NEVER use objects with `description` keys or nested structures. Mechanic parses option defaults as literal values:

```liquid
{% comment %} ✅ CORRECT - plain values only {% endcomment %}
{{ options.color__select_oRed_oBlue_oGreen }}  {% comment %} default: "Red" {% endcomment %}
{{ options.count__number }}                      {% comment %} default: 42 {% endcomment %}
{{ options.enabled__boolean }}                   {% comment %} default: true {% endcomment %}

{% comment %} ❌ WRONG - never use objects or nested structures {% endcomment %}
{% comment %} { "color": "red", "description": "..." } - INVALID! {% endcomment %}
```

**Common input types**:

```liquid
{{ options.subject }}                                # Plain text
{{ options.subject__required }}                      # Required text
{{ options.body__multiline }}                        # Multi-line textarea
{{ options.enabled__boolean }}                       # Checkbox
{{ options.count__number }}                          # Number input
{{ options.tags__array }}                            # String list
{{ options.recipients__email_array_required }}       # Email list (validated)
{{ options.headers__keyval }}                        # Key-value pairs
{{ options.mode__select_o1_test_o2_live }}          # Dropdown
{{ options.product__picker_product }}               # Shopify product picker
{{ options.products__picker_product_array }}        # Multi-product picker
{{ options.launch_date__date }}                      # Date picker
{{ options.score__range_min0_max100 }}              # Slider (0-100)
```

### Option Order Pattern

Control display order with comment block:

```liquid
{% comment %}
  Option order:

  {{ options.api_key__required }}
  {{ options.mode__select_o1_test_o2_live }}
  {{ options.notification_email__email }}
  {{ options.enabled__boolean }}
{% endcomment %}

{% comment %} Rest of task code {% endcomment %}
```

### Shopify Resource Pickers

Use pickers for better merchant UX:

```liquid
{% comment %}
  {{ options.product_to_monitor__picker_product__required }}
  {{ options.collections_to_sync__picker_collection_array }}
{% endcomment %}

{% assign product_id = options.product_to_monitor__picker_product__required %}

{% capture query %}
  query {
    product(id: {{ product_id | json }}) {
      id
      title
      variants(first: 250) {
        nodes { id inventoryQuantity }
      }
    }
  }
{% endcapture %}

{% assign result = query | shopify %}
```

### Custom Validation

Validate options with `{% error %}` tag:

```liquid
{% if options.maximum_value__number_required <= options.minimum_value__number_required %}
  {% error "'Maximum value' must be greater than 'Minimum value'." %}
{% endif %}

{% if options.recipients__email_array_required == blank %}
  {% error "At least one email recipient is required." %}
{% endif %}
```

**Complete documentation**: See `mechanic-task-options-reference.md` for all input types, validation patterns, and advanced features.

## Best Practices

### 1. Always Mock Preview Data

```liquid
{% if event.preview %}
  {% comment %} Mock all paths your logic uses {% endcomment %}
  {% capture result_json %}
    {
      "data": {
        "order": {
          "id": "gid://shopify/Order/1234",
          "lineItems": { "nodes": [...] }
        }
      }
    }
  {% endcapture %}
  {% assign result = result_json | parse_json %}
{% endif %}
```

### 2. Log Task Behavior

```liquid
{% log
  message: "Processing order",
  order_id: order.admin_graphql_api_id,
  items_count: order.lineItems.nodes.size
%}
```

### 3. Handle Errors Gracefully

```liquid
{% if result.data.productUpdate.userErrors != empty %}
  {% error message: "Failed to update", errors: result.data.productUpdate.userErrors %}
{% endif %}
```

### 4. Paginate Large Queries

```liquid
{% for n in (1..100) %}
  {% capture query %}
    query {
      orders(first: 250, after: {{ cursor | json }}) {
        pageInfo { hasNextPage endCursor }
        nodes { id }
      }
    }
  {% endcapture %}
  {% assign result = query | shopify %}
  {% if result.data.orders.pageInfo.hasNextPage == false %}
    {% break %}
  {% endif %}
  {% assign cursor = result.data.orders.pageInfo.endCursor %}
{% endfor %}
```

### 5. Prevent Action Loops

```liquid
{% if order.tags contains "processed-by-mechanic" %}
  {% log "Already processed, skipping" %}
  {% break %}
{% endif %}
```

### 6. Cache for Efficiency

```liquid
{% assign cache_key = "inventory-" | append: variant.id %}
{% assign previous = cache[cache_key] %}
{% if previous != variant.inventoryQuantity %}
  {% action "cache", "set", cache_key, variant.inventoryQuantity %}
{% endif %}
```

## Complete Task Examples

### Example 1: Auto-Tag High-Value Orders

```json
{
  "name": "Auto-tag orders over $100",
  "docs": "This task automatically tags orders with a value over $100 as 'high-value'.",
  "script": "{% if event.preview %}\n  {% assign order = hash %}\n  {% assign order[\"admin_graphql_api_id\"] = \"gid://shopify/Order/1234\" %}\n  {% assign order[\"name\"] = \"#1001\" %}\n  {% assign order[\"totalPriceSet\"] = hash %}\n  {% assign order[\"totalPriceSet\"][\"shopMoney\"] = hash %}\n  {% assign order[\"totalPriceSet\"][\"shopMoney\"][\"amount\"] = \"150.00\" %}\n{% endif %}\n\n{% assign threshold = options.threshold__number_required | default: 100 %}\n{% assign tag_to_add = options.tag__required | default: \"high-value\" %}\n\n{% assign order_value = order.totalPriceSet.shopMoney.amount | times: 1.0 %}\n\n{% if order_value > threshold %}\n  {% action \"shopify\" %}\n    mutation {\n      tagsAdd(\n        id: {{ order.admin_graphql_api_id | json }}\n        tags: {{ tag_to_add | json }}\n      ) {\n        userErrors { field message }\n      }\n    }\n  {% endaction %}\n  \n  {% log message: \"Tagged high-value order\", order: order.name, value: order_value %}\n{% endif %}",
  "subscriptions": ["shopify/orders/create"],
  "options": {
    "threshold__number_required": 100,
    "tag__required": "high-value"
  }
}
```

### Example 2: Send Review Request Email

```json
{
  "name": "Send review request 7 days after fulfillment",
  "docs": "Automatically sends a review request email to customers 7 days after their order has been fulfilled.",
  "script": "{% if event.topic == \"shopify/orders/fulfilled\" %}\n  {% action \"event\" %}\n    {\n      \"topic\": \"user/orders/review_request\",\n      \"data\": {\n        \"order_id\": {{ order.admin_graphql_api_id | json }},\n        \"customer_email\": {{ order.email | json }},\n        \"order_name\": {{ order.name | json }}\n      },\n      \"run_at\": {{ \"now\" | date: \"%s\", advance: \"7 days\" | json }}\n    }\n  {% endaction %}\n{% elsif event.topic == \"user/orders/review_request\" %}\n  {% assign customer_name = event.data.customer_email | split: \"@\" | first | capitalize %}\n  \n  {% assign email_subject = options.email_subject__required | replace: \"ORDER_NUMBER\", event.data.order_name %}\n  {% assign email_body = options.email_body__multiline_required | replace: \"CUSTOMER_NAME\", customer_name | replace: \"ORDER_NUMBER\", event.data.order_name %}\n  \n  {% action \"email\" %}\n    {\n      \"to\": {{ event.data.customer_email | json }},\n      \"subject\": {{ email_subject | strip | json }},\n      \"body\": {{ email_body | strip | newline_to_br | json }},\n      \"from_display_name\": {{ shop.name | json }},\n      \"reply_to\": {{ shop.customer_email | json }}\n    }\n  {% endaction %}\n{% endif %}\n\n{% if event.preview %}\n  {% if event.topic == \"shopify/orders/fulfilled\" %}\n    {% action \"event\" %}\n      {\n        \"topic\": \"user/orders/review_request\",\n        \"data\": {\n          \"order_id\": \"gid://shopify/Order/1234\",\n          \"customer_email\": \"customer@example.com\",\n          \"order_name\": \"#1001\"\n        },\n        \"run_at\": {{ \"now\" | date: \"%s\", advance: \"7 days\" | json }}\n      }\n    {% endaction %}\n  {% else %}\n    {% action \"email\" %}\n      {\n        \"to\": \"customer@example.com\",\n        \"subject\": \"Review your recent order #1001\",\n        \"body\": \"Hi there,<br><br>We hope you're enjoying your recent purchase from order #1001!<br><br>We'd love to hear your feedback.\"\n      }\n    {% endaction %}\n  {% endif %}\n{% endif %}",
  "subscriptions": ["shopify/orders/fulfilled", "user/orders/review_request"],
  "options": {
    "email_subject__required": "Review your recent order ORDER_NUMBER",
    "email_body__multiline_required": "Hi CUSTOMER_NAME,\n\nWe hope you're enjoying your recent purchase from order ORDER_NUMBER!\n\nWe'd love to hear your feedback. Please take a moment to review your purchase.\n\nThank you!\n{{ shop.name }}"
  }
}
```

## Output Format for AI Assistants

**IMPORTANT**: When creating tasks, always output the complete JSON structure that can be imported into Mechanic:

```json
{
  "name": "Task name here",
  "docs": "Clear description of what the task does and how to use it",
  "script": "{% comment %} The Liquid script code {% endcomment %}",
  "subscriptions": ["shopify/orders/create"],
  "options": {
    "setting_name__required": "default value"
  }
}
```

**DO NOT** output just the Liquid script. Users need the complete JSON to import the task.

**Note**: The `tags` field is only used in the mechanic-tasks library repository for categorization. It's not needed when creating or importing individual tasks.

## Task Quality Evaluation Checklist

When creating or reviewing tasks, ensure:

### Functionality

- [ ] Task accomplishes stated goal
- [ ] Handles edge cases appropriately
- [ ] Uses GraphQL (not REST)
- [ ] Implements proper pagination for large datasets
- [ ] Prevents infinite loops or action chains

### Code Quality

- [ ] Preview mode covers all code paths
- [ ] Comprehensive error handling
- [ ] Meaningful logging at key points
- [ ] Efficient queries (only requested fields)
- [ ] Proper use of caching where beneficial

### User Experience

- [ ] Clear, descriptive task name
- [ ] Documentation explains what and why
- [ ] Options have sensible defaults
- [ ] Email templates use UPPERCASE_WITH_UNDERSCORES placeholders
- [ ] Test mode option for safe testing

### Best Practices

- [ ] GraphQL IDs include namespace
- [ ] Numbers converted to strings for replacements
- [ ] Email bodies use `strip` and `newline_to_br`
- [ ] Actions check userErrors
- [ ] Sensitive data properly handled

## Workflow for Creating New Tasks

1. **Search existing tasks first**:

   ```bash
   # With MCP (preferred):
   mcp__mechanic-mcp__search_tasks query:"[your use case]"

   # Without MCP:
   # - Search at https://tasks.mechanic.dev/
   # - Or grep locally: grep -r "your use case" tasks/
   ```

2. **Review similar tasks for patterns**:

   ```bash
   # With MCP (preferred):
   mcp__mechanic-mcp__similar_tasks handle:"closest-match-task"

   # Without MCP:
   # - Browse related tasks in the same category
   # - Or find similar files: ls tasks/ | grep similar-keywords
   ```

3. **Write task following established patterns**

4. **Add comprehensive preview data**

5. **Test in Mechanic platform**:
   - Create or update task in Mechanic
   - Use preview mode to test without side effects
   - Verify actions and logs

6. **Validate and build docs**:

   ```bash
   npm run build && npm test
   ```

7. **Create PR with clear description**

## Common Gotchas

1. **Actions are ASYNC** - They run AFTER task completes, not inline!
2. **GraphQL IDs need namespace**: `{{ id | prepend: "gid://shopify/Product/" | json }}`
3. **Cannot read action results in same run** - Use mechanic/actions/perform
4. **Use GraphQL only** - REST is deprecated
5. **250 item limit per page** - always implement pagination
6. **20-second execution limit** - split large operations
7. **Placeholders should be UPPERCASE_WITH_UNDERSCORES**
8. **Convert numbers to strings**: `value | json | remove: '"'`
9. **Webhook data may be stale for delayed events** - refetch if needed
10. **Actions run in parallel by default** - Not sequential unless configured

## Shopify GraphQL Patterns

### Common Mutations

```liquid
{% comment %} Add tags to resource {% endcomment %}
{% action "shopify" %}
  mutation {
    tagsAdd(id: {{ resource_id | json }}, tags: ["tag1", "tag2"]) {
      userErrors { field message }
    }
  }
{% endaction %}

{% comment %} Update product {% endcomment %}
{% action "shopify" %}
  mutation {
    productUpdate(input: {
      id: {{ product_id | json }}
      title: {{ new_title | json }}
    }) {
      product { id }
      userErrors { field message }
    }
  }
{% endaction %}

{% comment %} Send order invoice {% endcomment %}
{% action "shopify" %}
  mutation {
    draftOrderInvoiceSend(
      id: {{ draft_order_id | json }}
      email: {
        to: {{ email | json }}
        subject: {{ subject | json }}
        customMessage: {{ message | json }}
      }
    ) {
      userErrors { field message }
    }
  }
{% endaction %}
```

### Common Queries

```liquid
{% comment %} Get order with line items {% endcomment %}
{% capture query %}
  query {
    order(id: {{ order_id | json }}) {
      id
      name
      email
      lineItems(first: 250) {
        nodes {
          id
          quantity
          variant {
            id
            sku
            product { id title }
          }
        }
      }
    }
  }
{% endcapture %}
{% assign result = query | shopify %}

{% comment %} Search products {% endcomment %}
{% capture query %}
  query {
    products(first: 250, query: "status:active AND tag:sale") {
      nodes {
        id
        title
        tags
        variants(first: 100) {
          nodes { id sku inventoryQuantity }
        }
      }
    }
  }
{% endcapture %}
{% assign result = query | shopify %}
```

**Tip**: Use the Shopify Dev MCP server to explore the complete GraphQL schema and available fields for each object type.

## Metafield Patterns

```liquid
{% assign parts = options.metafield_namespace_and_key__required | split: "." %}
{% assign namespace = parts[0] %}
{% assign key = parts[1] %}

{% action "shopify" %}
  mutation {
    metafieldsSet(
      metafields: [
        {
          ownerId: {{ product.id | json }}
          namespace: {{ namespace | json }}
          key: {{ key | json }}
          value: {{ value | json }}
          type: "single_line_text_field"
        }
      ]
    ) {
      userErrors { field message }
    }
  }
{% endaction %}
```

## File Generation Patterns

### CSV Export

```liquid
{% assign rows = array %}
{% assign header = array %}
{% assign header[0] = "Product Title" %}
{% assign header[1] = "SKU" %}
{% assign header[2] = "Inventory" %}
{% assign rows[0] = header %}

{% for product in products %}
  {% for variant in product.variants %}
    {% assign row = array %}
    {% assign row[0] = product.title %}
    {% assign row[1] = variant.sku %}
    {% assign row[2] = variant.inventoryQuantity %}
    {% assign rows[rows.size] = row %}
  {% endfor %}
{% endfor %}

{% action "files" %}
  {
    "inventory-report.csv": {
      "csv": {
        "rows": {{ rows | json }}
      }
    }
  }
{% endaction %}
```

### PDF Generation

```liquid
{% capture html %}
  <!DOCTYPE html>
  <html>
    <head>
      <style>
        table { border-collapse: collapse; }
        th, td { border: 1px solid #ddd; padding: 8px; }
      </style>
    </head>
    <body>
      <h1>Order {{ order.name }}</h1>
      <!-- content -->
    </body>
  </html>
{% endcapture %}

{% action "email" %}
  {
    "to": {{ email | json }},
    "subject": "Invoice",
    "attachments": {
      "invoice.pdf": {
        "pdf": { "html": {{ html | json }} }
      }
    }
  }
{% endaction %}
```

## Advanced Patterns

### Bulk Operation Processing

```liquid
{% if event.topic == "mechanic/user/trigger" %}
  {% capture bulk_query %}
    {
      products(query: "status:active") {
        edges {
          node {
            id
            title
            tags
            variants {
              edges {
                node {
                  id
                  inventoryQuantity
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
        query: {{ bulk_query | json }}
      ) {
        bulkOperation { id status }
        userErrors { field message }
      }
    }
  {% endaction %}
{% elsif event.topic == "mechanic/shopify/bulk_operation" %}
  {% assign products = bulkOperation.objects | where: "__typename", "Product" %}
  {% assign variants = bulkOperation.objects | where: "__typename", "ProductVariant" %}

  {% for variant in variants %}
    {% if variant.inventoryQuantity < 5 %}
      {% assign product = products | where: "id", variant.__parentId | first %}
      {% log product: product.title, variant: variant.id, inventory: variant.inventoryQuantity %}
    {% endif %}
  {% endfor %}
{% endif %}
```

### Error Thresholding

```liquid
{% assign error_key = "error_count/" | append: error_type %}
{% assign error_count = cache[error_key] | default: 0 | plus: 1 %}
{% action "cache", "set", error_key, error_count %}

{% assign alert_thresholds = "1,10,25,50,100" | split: "," %}
{% if alert_thresholds contains error_count %}
  {% action "email" %}
    {
      "to": {{ options.admin_email__email_required | json }},
      "subject": "Error threshold reached: {{ error_type }}",
      "body": "Error count: {{ error_count }}"
    }
  {% endaction %}
{% endif %}
```

## Key Liquid Filters

- `shopify` - Execute GraphQL queries
- `json` / `parse_json` - JSON handling
- `date` - Date manipulation: `"now" | date: "%Y-%m-%d"`
- `prepend` / `append` - String concatenation
- `split` / `join` - Array operations
- `where` / `map` - Collection filtering
- `in_groups_of` - Batch processing
- `strip` / `newline_to_br` - Text formatting
- `currency` - Format money values
- `graphql_arguments` - Format for mutations
- `base64` / `base64_decode` - Encoding
- `sha256` / `hmac_sha256` - Cryptographic hashing

## Event Subscriptions

Common patterns:

- Shopify webhooks: `shopify/orders/create`, `shopify/customers/update`
- Scheduled: `mechanic/scheduler/daily`, `mechanic/scheduler/10min`
- Delayed: `shopify/orders/create+30.days`
- Manual: `mechanic/user/trigger`
- Action responses: `mechanic/actions/perform`
- Bulk operations: `mechanic/shopify/bulk_operation`

## Troubleshooting Common Issues

### Issue: "GraphQL error: Variable $id of type ID! was provided invalid value"

**Cause**: Missing or incorrect namespace in GraphQL ID

**Fix**:

```liquid
{% comment %} Wrong {% endcomment %}
{{ product_id | json }}

{% comment %} Correct {% endcomment %}
{{ product_id | prepend: "gid://shopify/Product/" | json }}
```

### Issue: "Task exceeded execution time limit"

**Cause**: Processing too many items in a single run

**Fix**: Use bulk operations or implement pagination:
```liquid
{% comment %} Instead of processing all at once {% endcomment %}
{% capture bulk_query %}
  { products { edges { node { id } } } }
{% endcapture %}

{% action "shopify" %}
  mutation {
    bulkOperationRunQuery(
      query: {{ bulk_query | json }}
    ) {
      bulkOperation { id }
      userErrors { field message }
    }
  }
{% endaction %}
```

### Issue: "Email not sending with placeholders"

**Cause**: Placeholders not being replaced or incorrect formatting

**Fix**:
```liquid
{% comment %} Ensure proper string conversion {% endcomment %}
{% assign value_string = numeric_value | json | remove: '"' %}
{% assign email_body = email_body | replace: "PLACEHOLDER", value_string %}
```

### Issue: "Infinite loop detected"

**Cause**: Task triggering itself through actions

**Fix**: Add loop prevention:
```liquid
{% unless event.parent %}
  {% comment %} Only process if this is not a child event {% endcomment %}
  {% action "shopify" %}...{% endaction %}
{% endunless %}
```

### Issue: "Preview mode shows no actions"

**Cause**: Incomplete preview data

**Fix**: Ensure preview covers all code paths:
```liquid
{% if event.preview %}
  {% comment %} Mock ALL required data {% endcomment %}
  {% assign order = hash %}
  {% assign order["id"] = "gid://shopify/Order/1234" %}
  {% assign order["fulfillmentStatus"] = "UNFULFILLED" %}
  {% comment %} Include all fields your logic checks {% endcomment %}
{% endif %}
```

## Security Best Practices

### 1. Input Validation

Always validate user inputs from options:
```liquid
{% if options.email__email_required == blank %}
  {% error "Email is required" %}
{% endif %}

{% if options.threshold__number < 0 %}
  {% error "Threshold must be positive" %}
{% endif %}
```

### 2. Webhook Verification

Verify webhook authenticity in sensitive tasks:
```liquid
{% comment %} Only process genuine Shopify webhooks {% endcomment %}
{% if event.topic contains "shopify/" %}
  {% comment %} Process webhook {% endcomment %}
{% elsif event.topic == "mechanic/user/trigger" %}
  {% comment %} Manual trigger - verify intent {% endcomment %}
{% else %}
  {% log "Unexpected event source", topic: event.topic %}
{% endif %}
```

### 3. Sanitize External Data

Clean data before using in mutations:
```liquid
{% assign safe_tag = untrusted_input | strip | slice: 0, 40 %}
{% if safe_tag contains "<" or safe_tag contains ">" %}
  {% error "Invalid characters in tag" %}
{% endif %}
```

### 4. Rate Limit Protection

Implement throttling for expensive operations:
```liquid
{% assign last_run_key = "last_run_" | append: task.id %}
{% assign last_run = cache[last_run_key] | default: 0 %}
{% assign time_since = "now" | date: "%s" | minus: last_run %}

{% if time_since < 300 %}  {% comment %} 5 minute cooldown {% endcomment %}
  {% log "Skipping - ran recently", seconds_ago: time_since %}
  {% break %}
{% endif %}

{% action "cache", "set", last_run_key, "now" | date: "%s" %}
```

## Performance Optimization

### 1. Query Only What You Need

```liquid
{% comment %} Bad - fetches everything {% endcomment %}
query { products(first: 250) { nodes {
  id title description handle tags images {...}
}}}

{% comment %} Good - fetches only required fields {% endcomment %}
query { products(first: 250) { nodes {
  id title tags
}}}
```

### 2. Use Caching Strategically

```liquid
{% assign cache_key = "expensive_calculation_" | append: product.id %}
{% assign cached_result = cache[cache_key] %}

{% if cached_result == blank %}
  {% comment %} Perform expensive calculation {% endcomment %}
  {% assign result = ... %}
  {% action "cache", "set", cache_key, result %}
{% else %}
  {% assign result = cached_result %}
  {% log "Using cached value", key: cache_key %}
{% endif %}
```

### 3. Batch Operations

```liquid
{% comment %} Instead of multiple individual mutations {% endcomment %}
{% assign metafields_to_set = array %}

{% for product in products %}
  {% assign metafield = hash %}
  {% assign metafield["ownerId"] = product.id %}
  {% assign metafield["namespace"] = "custom" %}
  {% assign metafield["key"] = "value" %}
  {% assign metafields_to_set = metafields_to_set | push: metafield %}
{% endfor %}

{% comment %} Batch update (max 25 at a time) {% endcomment %}
{% assign groups = metafields_to_set | in_groups_of: 25, fill_with: false %}
{% for group in groups %}
  {% action "shopify" %}
    mutation {
      metafieldsSet(metafields: {{ group | graphql_arguments }}) {
        userErrors { field message }
      }
    }
  {% endaction %}
{% endfor %}
```

### 4. Early Exits

```liquid
{% comment %} Exit early when conditions aren't met {% endcomment %}
{% unless order.tags contains "process-me" %}
  {% log "Order doesn't need processing", order: order.name %}
  {% break %}
{% endunless %}

{% comment %} Rest of task logic {% endcomment %}
```

## Advanced Task Composition (From Real Tasks)

### Pattern 1: Cache-Based State Tracking

From "Accept a maximum number of orders per day" - tracking state across events:

```liquid
{% comment %} Track whether action has been taken today {% endcomment %}
{% assign state_cache_key = "inventory_is_zeroed:" | append: task.id %}
{% assign inventory_is_zeroed = cache[state_cache_key] | default: false %}

{% if condition_met and inventory_is_zeroed == false %}
  {% comment %} Perform action and mark as done {% endcomment %}
  {% action "cache", "set", state_cache_key, true %}

  {% comment %} Do the work... {% endcomment %}
{% endif %}

{% comment %} Reset on daily schedule {% endcomment %}
{% if event.topic == "mechanic/scheduler/daily" %}
  {% action "cache", "del", state_cache_key %}
{% endif %}
```

### Pattern 2: Storing Complex Data for Later Restoration

From "Accept a maximum number of orders per day" - saving and restoring inventory:

```liquid
{% comment %} Store data in cache with structured keys {% endcomment %}
{% assign base_cache_key = "inventory_to_restore:" | append: timestamp %}
{% assign groups_of_adjustments = adjustments | in_groups_of: 250, fill_with: false %}

{% for group in groups_of_adjustments %}
  {% assign cache_key = base_cache_key | append: "_group" | append: forloop.index0 %}
  {% assign cache_value = hash %}
  {% assign cache_value["value"] = group %}

  {% unless forloop.last %}
    {% assign next_cache_key = base_cache_key | append: "_group" | append: forloop.index %}
    {% assign cache_value["next_key"] = next_cache_key %}
  {% endunless %}

  {% action "cache", "set", cache_key, cache_value %}
{% endfor %}

{% comment %} Later, restore by walking the chain {% endcomment %}
{% for n in (0..1000) %}
  {% assign data = cache[cache_key] %}
  {% comment %} Process data.value {% endcomment %}

  {% if data.next_key %}
    {% assign cache_key = data.next_key %}
  {% else %}
    {% break %}
  {% endif %}
{% endfor %}
```

### Pattern 3: Event Chaining for Multi-Step Processes

From "Advanced: Scheduled Price Changes" - coordinating multiple events:

```liquid
{% comment %} Schedule start and end events {% endcomment %}
{% action "event" %}
  {
    "topic": "user/price_changes/start",
    "data": { "products": {{ product_ids | json }} },
    "run_at": {{ start_time | date: "%s" | json }}
  }
{% endaction %}

{% action "event" %}
  {
    "topic": "user/price_changes/end",
    "data": { "products": {{ product_ids | json }} },
    "run_at": {{ end_time | date: "%s" | json }}
  }
{% endaction %}

{% comment %} Different handling for each event {% endcomment %}
{% case event.topic %}
{% when "user/price_changes/start" %}
  {% comment %} Apply sale prices {% endcomment %}
{% when "user/price_changes/end" %}
  {% comment %} Restore original prices {% endcomment %}
{% endcase %}
```

## Common Error Patterns Reference

| Error | Cause | Solution |
| --- | --- | --- |
| "Cannot read property 'nodes' of undefined" | Missing null check on GraphQL response | Add `if result.data.field` check |
| "Liquid syntax error" | Unclosed tags or invalid syntax | Check all `{% if %}` have `{% endif %}` |
| "Task memory exceeded" | Processing too much data | Use bulk operations or pagination |
| "Invalid mutation argument" | Wrong GraphQL argument format | Use `graphql_arguments` filter |
| "Shop API rate limit" | Too many API calls | Implement caching and batching |

## Remember: The Mechanic Mental Model

### 🔑 The Three Fundamentals

1. **The `shopify` filter is the ONLY inline operation** - Returns results immediately
2. **EVERYTHING else is ASYNC** - ALL actions queue and run after task completes
3. **READ vs WRITE**:
   - `query | shopify` = Synchronous read (the ONLY sync operation!)
   - `{% action "shopify" %}` = Async write (runs after task ends)
   - **No other filters or operations return inline results from external systems**

### Execution Timeline

```text
Time →
[EVENT] → [TASK RUNS] → [TASK ENDS] → [ACTIONS RUN] → [NEW EVENTS]
           ↓                            ↑
           READ (filter)                WRITE (action)
           Results immediate            Runs after task completes
```

### Essential Checklist

- ✅ Always search existing tasks before creating new ones
- ✅ Understand ASYNC: Actions run AFTER task completes
- ✅ READ with filters (immediate), WRITE with actions (async)
- ✅ Use GraphQL, never REST
- ✅ Mock comprehensive preview data
- ✅ Log important operations
- ✅ Handle errors gracefully
- ✅ Prevent infinite loops
- ✅ Test in platform using preview mode
- ✅ Use placeholders in UPPERCASE_WITH_UNDERSCORES
- ✅ Convert numbers to strings for replacements: `value | json | remove: '"'`
- ✅ Always apply `strip` and `newline_to_br` to email bodies
- ✅ Leverage MCP servers for task discovery and documentation
- ✅ Validate all inputs
- ✅ Optimize queries for performance
- ✅ Handle mechanic/actions/perform for action results
