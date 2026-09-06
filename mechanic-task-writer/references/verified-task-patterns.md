# Verified Task Patterns

These examples have offline behavior checks against Mechanic’s Liquid renderer. Adapt their data and subscriptions to the task; they do not prove live API behavior.

### Two-Pass Pattern (mechanic/actions/perform)

Example: tag a paid order, then notify an operator only after the Shopify action succeeds. Subscribe to both `shopify/orders/paid` and `mechanic/actions/perform`. Each branch queues only its own stage; never put the first action above the event-topic guard.

```liquid
{% comment %}
  {{ options.tag_to_add__required }}
  {{ options.notification_email__email_required }}
{% endcomment %}

{% if event.topic == "shopify/orders/paid" %}
  {% if event.preview %}
    {% assign order = hash %}
    {% assign order["admin_graphql_api_id"] = "gid://shopify/Order/1234567890" %}
    {% assign order["name"] = "#1001" %}
  {% endif %}

  {% assign meta = hash %}
  {% assign meta["stage"] = "tag_order" %}
  {% assign meta["order_name"] = order.name %}
  {% assign meta["recipient"] = options.notification_email__email_required %}
  {% action "shopify", __meta: meta %}
    mutation {
      tagsAdd(id: {{ order.admin_graphql_api_id | json }}, tags: {{ options.tag_to_add__required | json }}) {
        userErrors { field message }
      }
    }
  {% endaction %}

{% elsif event.topic == "mechanic/actions/perform" %}
  {% if event.preview %}
    {% capture action_json %}
      {
        "type": "shopify",
        "meta": {
          "stage": "tag_order",
          "order_name": "#1001",
          "recipient": {{ options.notification_email__email_required | json }}
        },
        "run": {"ok": true, "result": {"data": {"tagsAdd": {"userErrors": []}}}}
      }
    {% endcapture %}
    {% assign action = action_json | parse_json %}
  {% endif %}

  {% if action.type != "shopify" or action.meta.stage != "tag_order" %}
    {% break %}
  {% endif %}
  {% unless action.run.ok %}
    {% log "Tagging failed; no confirmation email sent.", error: action.run.error %}
    {% break %}
  {% endunless %}

  {% assign subject = "Tagged order " | append: action.meta.order_name %}
  {% action "email", __perform_event: false %}
    {
      "to": {{ action.meta.recipient | json }},
      "subject": {{ subject | json }},
      "body": "The Shopify tagging action completed successfully."
    }
  {% endaction %}
{% endif %}
```

Mechanic marks a Shopify action as failed when its response contains top-level GraphQL errors or mutation `userErrors`. Select `userErrors` in the mutation and check `action.run.ok` before using its result or announcing success. Use `action.run.result.data` only in a successful callback. If the next step needs a created resource ID, also check that the expected result object and ID exist.

Pass state through `__meta` / `action.meta`, rather than expecting local variables or the original `order` to survive across runs. Set `__perform_event: false` on terminal actions that need no callback; retain callbacks on intermediate actions needed by a later stage. Sequencing settings order action execution within one task run; they do not make action results available synchronously or serialize separate task runs.

### test_mode Pattern

This snippet assumes `customer` came from GraphQL, where `customer.id` is a GID. For a customer webhook, use `customer.admin_graphql_api_id`.

For tasks that benefit from a live dry run, add a `test_mode__boolean` option and document it. On live test-mode runs, emit Echo actions instead of side effects. During preview, still render the real actions for permission discovery (Mechanic does not execute them). Apply test mode to every side-effect branch, including email and follow-up actions. Echo does not generate action callbacks, so a two-pass dry run cannot depend on an Echo callback.

```liquid
{% if options.test_mode__boolean and event.preview != true %}
  {% action "echo" customer_id: customer.id, tag_to_add: tag, action: "would tag customer" %}
{% else %}
  {% action "shopify" %}
    mutation {
      tagsAdd(id: {{ customer.id | json }}, tags: {{ tag | json }}) {
        userErrors { field message }
      }
    }
  {% endaction %}
{% endif %}
```

### Email with Placeholder Template

Liquid quoted strings do not interpret backslash-n as a newline. Use a `capture` block containing real newlines for a multiline body, then apply `newline_to_br` for an HTML email.

This example uses an order webhook. For GraphQL data, use the names you selected in the query instead. Apply a fallback to the replacement value before inserting it into the template.
```liquid
{% comment %}
  {{ options.email_subject__required }}
  {{ options.email_body__multiline_required }}
{% endcomment %}

{% assign customer_name = order.customer.first_name | default: "there" %}
{% assign email_subject = options.email_subject__required
  | replace: "ORDER_NUMBER", order.name %}
{% assign email_body = options.email_body__multiline_required
  | replace: "CUSTOMER_NAME", customer_name
  | replace: "ORDER_NUMBER", order.name %}

{% action "email" %}
  {
    "to": {{ order.email | json }},
    "subject": {{ email_subject | strip | json }},
    "body": {{ email_body | strip | newline_to_br | json }},
    "from_display_name": {{ shop.name | json }},
    "reply_to": {{ shop.customer_email | json }}
  }
{% endaction %}
```

### Pagination

Paginate every connection whose full contents matter, including nested connections; `first: 250` is only one page. Prefer bulk queries for unbounded exports or backfills. The bounded example below fails explicitly if its limit is exhausted, instead of silently reporting a complete result. It demonstrates pagination only; add the requested processing where indicated.
```liquid
{% assign cursor = nil %}

{% for n in (1..100) %}
  {% capture query %}
    query {
      orders(first: 250, after: {{ cursor | json }}) {
        pageInfo { hasNextPage endCursor }
        nodes { id name }
      }
    }
  {% endcapture %}
  {% assign result = query | shopify %}
  {% if event.preview %}
    {% capture result_json %}
      {"data":{"orders":{"nodes":[{"id":"gid://shopify/Order/1234567890","name":"#1001"}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}
    {% endcapture %}
    {% assign result = result_json | parse_json %}
  {% endif %}
  {% if result.data.orders == nil %}
    {% error "The orders query returned no connection; cannot complete processing." %}
    {% break %}
  {% endif %}
  {% comment %} Process result.data.orders.nodes here. {% endcomment %}
  {% if result.data.orders.pageInfo.hasNextPage %}
    {% assign next_cursor = result.data.orders.pageInfo.endCursor %}
    {% if next_cursor == blank or next_cursor == cursor %}
      {% error "Pagination did not advance; cannot complete processing." %}
      {% break %}
    {% endif %}
    {% assign cursor = next_cursor %}
  {% else %}
    {% break %}
  {% endif %}
{% endfor %}
{% if result.data.orders.pageInfo.hasNextPage %}
  {% error "Pagination limit reached. Use a bulk query or narrow the selection." %}
{% endif %}
```

## Runtime sources

- `mechanic-api/app/lib/mechanic/actions/shopify_action.rb`: GraphQL and mutation errors fail the action.
- `mechanic-api/app/lib/mechanic/liquid/tags/action_tag.rb`: action output and metadata controls.
- `mechanic-api/app/lib/mechanic/liquid/tags/error_tag.rb` and `app/models/task_run.rb`: rendered errors fail the task before action staging; the tag alone does not terminate Liquid.
- `mechanic-api/app/models/concerns/event/liquid_concern.rb`: event variables and normalized user-form input.
- [Mechanic previews](https://learn.mechanic.dev/core/tasks/previews) and [action results](https://learn.mechanic.dev/techniques/responding-to-action-results).
