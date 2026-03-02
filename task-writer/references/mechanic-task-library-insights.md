# Mechanic Task Library Insights

Curated wisdom from analyzing 359 production tasks in the Mechanic task library.

## Library Statistics

**Total Tasks**: 359
**Library URL**: https://tasks.mechanic.dev
**Repository**: https://github.com/lightward/mechanic-tasks

### Top Categories (by tag)

1. **Orders** (125 tasks) - Order processing, automation, validation
2. **Auto-Tag** (102 tasks) - Automated tagging workflows
3. **Products** (97 tasks) - Product management, updates, publishing
4. **Customers** (73 tasks) - Customer management, segmentation
5. **Email** (64 tasks) - Notifications, reports, communications
6. **Tag** (38 tasks) - General tagging operations
7. **Watch** (28 tasks) - Monitoring and alerting
8. **Inventory** (28 tasks) - Stock management, tracking
9. **Shipping** (25 tasks) - Fulfillment, tracking
10. **Metafields** (24 tasks) - Custom data management

### Most Common Event Subscriptions

1. **shopify/orders/create** (86 tasks) - New order processing
2. **shopify/products/update** (26 tasks) - Product change reactions
3. **shopify/orders/updated** (24 tasks) - Order modifications
4. **shopify/products/create** (22 tasks) - New product handling
5. **shopify/orders/paid** (21 tasks) - Payment confirmation triggers
6. **shopify/customers/create** (19 tasks) - New customer workflows
7. **shopify/inventory_levels/update** (18 tasks) - Stock monitoring
8. **shopify/customers/update** (14 tasks) - Customer data changes
9. **shopify/orders/fulfilled** (6 tasks) - Fulfillment completion
10. **shopify/fulfillments/create** (6 tasks) - New fulfillment events

### Common Event Combinations

Tasks often subscribe to multiple events for comprehensive automation:

**Order Lifecycle**:
```json
[
  "shopify/orders/create",
  "shopify/orders/updated",
  "shopify/orders/paid"
]
```

**Daily + Manual Trigger**:
```json
[
  "mechanic/scheduler/daily",
  "mechanic/user/trigger"
]
```

**Product Publishing Workflow**:
```json
[
  "shopify/products/create",
  "shopify/products/update",
  "mechanic/user/trigger"
]
```

**Inventory Monitoring**:
```json
[
  "shopify/inventory_levels/update",
  "mechanic/scheduler/daily"
]
```

## Preview Event Adoption

**Tasks with preview_event_definitions**: 85 (24%)
**Tasks without preview data**: 274 (76%)

**Insight**: Most tasks rely on in-code preview mocking with `if event.preview` blocks rather than defined preview events.

**Common Preview Pattern**:
```liquid
{% if event.preview %}
  {% assign order = hash %}
  {% assign order["id"] = "gid://shopify/Order/1234567890" %}
  {% assign order["name"] = "#1001" %}
  {% assign order["email"] = "customer@example.com" %}
{% endif %}
```

## Real-World Error Handling Patterns

### Pattern 1: GraphQL userErrors Check

**Found in**: 90%+ of Shopify mutation tasks

```liquid
{% action "shopify" %}
  mutation {
    tagsAdd(id: {{ id | json }}, tags: {{ tags | json }}) {
      userErrors { field message }
    }
  }
{% endaction %}
```

**Note**: Most tasks don't explicitly check userErrors in mechanic/actions/perform, relying on Mechanic's automatic error detection.

### Pattern 2: Option Validation Before Processing

**Found in**: 60%+ of complex tasks

```liquid
{% if options.value__number_required <= 0 %}
  {% error "Value must be positive." %}
{% endif %}
```

### Pattern 3: Conditional Logic with Breaks

**Found in**: 40%+ of tasks

```liquid
{% if condition_not_met %}
  {% log "Condition not met, exiting early" %}
  {% break %}
{% endif %}
```

## GraphQL Query Optimization Patterns

### Pattern 1: Request Only Needed Fields

**Good**:
```liquid
query {
  product(id: {{ id | json }}) {
    id
    title
    status
  }
}
```

**Avoid**:
```liquid
query {
  product(id: {{ id | json }}) {
    # Don't request entire product object
  }
}
```

### Pattern 2: Batch Processing with Pagination

**Found in**: Tasks processing 100+ items

```liquid
{% for n in (1..100) %}
  {% capture query %}
    query {
      products(first: 250, after: {{ cursor | json }}) {
        pageInfo { hasNextPage endCursor }
        nodes { id title }
      }
    }
  {% endcapture %}
  {% assign result = query | shopify %}

  {% comment %} Process batch {% endcomment %}

  {% if result.data.products.pageInfo.hasNextPage %}
    {% assign cursor = result.data.products.pageInfo.endCursor %}
  {% else %}
    {% break %}
  {% endif %}
{% endfor %}
```

### Pattern 3: Bulk Operations for Large Datasets

**Found in**: Tasks analyzing entire catalog

```liquid
{% if event.topic == "mechanic/user/trigger" %}
  {% capture bulk_query %}
    {
      products {
        edges {
          node {
            __typename
            id
            variants {
              edges {
                node {
                  __typename
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
      bulkOperationRunQuery(query: {{ bulk_query | json }}) {
        bulkOperation { id status }
        userErrors { field message }
      }
    }
  {% endaction %}
{% elsif event.topic == "mechanic/shopify/bulk_operation" %}
  {% assign products = bulkOperation.objects | where: "__typename", "Product" %}
  {% assign variants = bulkOperation.objects | where: "__typename", "ProductVariant" %}
  {% comment %} Process data {% endcomment %}
{% endif %}
```

## Tag Naming Conventions

### Common Tag Patterns

**Status Tags**:
- `processed`, `processed-by-mechanic`
- `reviewed`, `needs-review`
- `verified`, `pending-verification`

**Date Tags**:
- `created-YYYY-MM-DD`
- `last-updated-YYYY-MM-DD`

**Threshold Tags**:
- `high-value`, `vip`, `wholesale`
- `low-stock`, `out-of-stock`

**Source Tags**:
- `imported`, `manual`
- `migrated`, `auto-created`

### Anti-Loop Tags

**Critical Pattern**: Always check for processing tags to prevent loops

```liquid
{% if order.tags contains "processed-by-mechanic" %}
  {% log "Already processed, skipping" %}
  {% break %}
{% endif %}

{% action "shopify" %}
  mutation {
    tagsAdd(
      id: {{ order.id | json }}
      tags: ["processed-by-mechanic", "other-tag"]
    ) {
      userErrors { field message }
    }
  }
{% endaction %}
```

## Logging Best Practices from Production Tasks

### Pattern 1: Log Why Nothing Happened

**Critical for support**:

```liquid
{% if eligible_orders == empty %}
  {% log "No eligible orders found", query_used: query %}
  {% break %}
{% else %}
  {% log orders_found: eligible_orders.size %}
{% endif %}
```

### Pattern 2: Log Before Destructive Actions

```liquid
{% log
  message: "Deleting customer",
  customer_id: customer.id,
  customer_email: customer.email,
  reason: "inactive for 2 years"
%}

{% action "shopify" %}
  mutation {
    customerDelete(input: { id: {{ customer.id | json }} }) {
      userErrors { field message }
    }
  }
{% endaction %}
```

### Pattern 3: Structured Logging for Debugging

```liquid
{% log
  task_stage: "validation",
  orders_processed: orders.size,
  cache_state: cache["daily_count"],
  threshold_met: orders.size >= threshold,
  will_send_alert: should_alert
%}
```

## Option Design Patterns

### Pattern 1: Test Mode

**Found in**: 40%+ of mutation tasks

```liquid
{% comment %}
  {{ options.test_mode__boolean }}
{% endcomment %}

{% if options.test_mode__boolean %}
  {% log "TEST MODE: Would perform action", action_data: data %}
{% else %}
  {% action "shopify" %}...{% endaction %}
{% endif %}
```

### Pattern 2: Email Template with Placeholders

**Found in**: 80%+ of email tasks

```liquid
{% comment %}
  {{ options.email_subject__required }}
  {{ options.email_body__multiline_required }}
{% endcomment %}

{% assign subject = options.email_subject__required | replace: "ORDER_NUMBER", order.name %}
{% assign body = options.email_body__multiline_required | replace: "CUSTOMER_NAME", customer.firstName %}
```

### Pattern 3: Optional Query Filter

```liquid
{% comment %}
  {{ options.additional_order_filter }}
{% endcomment %}

{% capture query %}
  created_at:>={{ start_date | json }}
  {{ options.additional_order_filter }}
{% endcapture %}

{% assign query = query | strip %}
```

## Common Task Structures

### Simple Task (50% of library)

```liquid
{% comment %} Minimal: Direct event → action {% endcomment %}

{% action "shopify" %}
  mutation {
    tagsAdd(id: {{ order.id | json }}, tags: ["paid"]) {
      userErrors { field message }
    }
  }
{% endaction %}
```

### Moderate Task (35% of library)

```liquid
{% comment %} Query → Process → Action {% endcomment %}

{% capture query %}
  query {
    order(id: {{ order.id | json }}) {
      lineItems(first: 250) {
        nodes { id quantity }
      }
    }
  }
{% endcapture %}

{% assign result = query | shopify %}

{% for item in result.data.order.lineItems.nodes %}
  {% if item.quantity > 5 %}
    {% action "shopify" %}...{% endaction %}
  {% endif %}
{% endfor %}
```

### Complex Task (15% of library)

```liquid
{% comment %} Multi-event, stateful, with cache and scheduling {% endcomment %}

{% if event.topic == "shopify/orders/create" %}
  {% comment %} Stage 1 {% endcomment %}
  {% action "cache", "set", key, value %}
  {% action "event" %}...{% endaction %}

{% elsif event.topic == "mechanic/actions/perform" %}
  {% comment %} Stage 2 {% endcomment %}
  {% if action.type == "http" %}
    {% action "shopify" %}...{% endaction %}
  {% endif %}

{% elsif event.topic == "mechanic/scheduler/daily" %}
  {% comment %} Cleanup {% endcomment %}
  {% action "cache", "del", key %}
{% endif %}
```

## Subscription Patterns

### Daily Tasks

**Subscription**:
```json
["mechanic/scheduler/daily"]
```

**Common uses**:
- Reports
- Cleanup operations
- Batch processing
- Cache resets

### User-Triggered with Scheduler Combo

**Subscription**:
```json
[
  "mechanic/scheduler/daily",
  "mechanic/user/trigger"
]
```

**Benefits**:
- Automated + on-demand execution
- Same code path for both
- Easy testing via "Run task"

### Delayed Subscription (Use Sparingly)

**Subscription**:
```json
["shopify/orders/create+7.days"]
```

**Better alternative**: Use daily scheduler with date queries

## Action Type Usage Frequency

Based on grep analysis:

1. **Shopify actions**: Most common (tagging, updates, queries)
2. **Email actions**: Second most common
3. **Cache actions**: Growing usage for state management
4. **HTTP actions**: External API integrations
5. **Event actions**: Workflow chaining
6. **Files actions**: Reports, exports

## Field Selection Patterns

### Orders

**Always include**:
- `id`
- `name`
- `email`

**Commonly needed**:
- `tags`
- `lineItems { nodes { id quantity product { id } } }`
- `totalPriceSet { shopMoney { amount currencyCode } }`
- `createdAt`
- `displayFinancialStatus`
- `displayFulfillmentStatus`

### Products

**Always include**:
- `id`
- `title`
- `status`

**Commonly needed**:
- `tags`
- `variants(first: 250) { nodes { id sku inventoryQuantity } }`
- `metafields(first: 10) { nodes { namespace key value } }`
- `publishedAt`

### Customers

**Always include**:
- `id`
- `email`
- `displayName`

**Commonly needed**:
- `tags`
- `orders(first: 250) { nodes { id totalPriceSet } }`
- `amountSpent { amount }`
- `ordersCount`
- `createdAt`

## Performance Optimization Insights

### 1. Limit Deep Nesting

**Avoid**:
```liquid
orders {
  lineItems {
    product {
      variants {
        metafields { ... }
      }
    }
  }
}
```

**Better**: Use bulk operations or multiple queries

### 2. Use `first` Limits Wisely

**Found in production**:
- `first: 250` for most connections (Shopify max)
- `first: 10` for metafields (rarely need more)
- `first: 5` for preview data

### 3. Cache Expensive Queries

**Pattern from library**:
```liquid
{% assign cache_key = "product_data:" | append: product.id %}
{% assign cached_data = cache[cache_key] %}

{% if cached_data == blank %}
  {% capture query %}...{% endcapture %}
  {% assign result = query | shopify %}
  {% action "cache", "set", cache_key, result.data %}
  {% assign data = result.data %}
{% else %}
  {% assign data = cached_data %}
{% endif %}
```

## Task Quality Indicators

**High-quality tasks** in the library consistently feature:

1. ✅ Preview data (even if simple)
2. ✅ Option validation
3. ✅ Logging (especially "why nothing happened")
4. ✅ Clear task documentation
5. ✅ Loop prevention (tags or cache)
6. ✅ Error handling in GraphQL mutations
7. ✅ Sensible default options
8. ✅ Test mode option
9. ✅ Structured logging with context
10. ✅ Appropriate pagination for large datasets

## Common Mistakes to Avoid

Based on less polished tasks:

1. ❌ No preview data
2. ❌ No logging when conditions aren't met
3. ❌ Missing loop prevention
4. ❌ Hardcoded values instead of options
5. ❌ No pagination for potentially large datasets
6. ❌ Overly complex queries requesting unnecessary fields
7. ❌ No test mode for destructive operations
8. ❌ Poor option naming (unclear labels)
9. ❌ Missing validation for required options
10. ❌ No documentation

## Task Naming Conventions

**Pattern**: `<Action>-<Subject>-<Condition/Timing>`

**Examples from library**:
- `auto-tag-orders-when-paid`
- `email-customers-when-tagged`
- `sync-inventory-across-locations`
- `alert-when-product-quantity-low`
- `archive-orders-after-fulfillment`
- `send-email-a-week-after-order`

**Best practices**:
- Start with verb (auto-tag, send, sync, alert, archive)
- Be specific about subject (orders, customers, products)
- Include trigger/condition when relevant

## JSON Export Fields

Standard fields found in all task exports:

```json
{
  "name": "Task name",
  "docs": "Documentation with first paragraph as summary",
  "script": "Liquid code",
  "subscriptions": ["array", "of", "topics"],
  "subscriptions_template": "newline-separated for UI",
  "options": {},
  "tags": ["Category", "Tags"],
  "halt_action_run_sequence_on_error": false,
  "perform_action_runs_in_sequence": false,
  "online_store_javascript": null,
  "order_status_javascript": null,
  "preview_event_definitions": []
}
```

## Advanced Settings Usage

**halt_action_run_sequence_on_error**:
- `true` in ~5% of tasks
- Used when order matters and failures should stop processing

**perform_action_runs_in_sequence**:
- `true` in ~10% of tasks
- Used when actions must execute in order (e.g., GraphQL mutations depending on each other)

## Resources

- **Browse tasks**: https://tasks.mechanic.dev
- **Search with MCP**: `mcp__mechanic-mcp__search_tasks`
- **GitHub repo**: https://github.com/lightward/mechanic-tasks
- **Contributing**: https://learn.mechanic.dev/resources/task-library/contributing
