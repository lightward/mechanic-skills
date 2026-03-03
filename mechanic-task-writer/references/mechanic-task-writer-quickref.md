# Mechanic Task Writer - Quick Reference Card

## ⚠️ CRITICAL: Only `shopify` Filter is SYNC!

```liquid
{% comment %} ✅ The ONLY synchronous operation {% endcomment %}
{% assign result = query | shopify %}
{% log result.data %}  {% comment %} Works immediately! {% endcomment %}

{% comment %} ❌ EVERYTHING else is async {% endcomment %}
{% action "shopify" %}...{% endaction %}
{% comment %} Action hasn't run yet! Can't use result! {% endcomment %}
```

## 🎯 Task Output Format (REQUIRED)

**AI ASSISTANTS**: Always output complete JSON tasks, not just scripts!

```json
{
  "name": "Task display name",
  "docs": "First paragraph becomes summary. Full description follows...",
  "script": "{% comment %} Complete Liquid code here {% endcomment %}",
  "subscriptions": ["shopify/orders/create"],
  "options": {
    "field__required": "default",
    "number__number_required": 10
  }
}
```

This JSON can be directly imported into Mechanic via the task import feature.

## ⚡ Essential Liquid Snippets

### READ from Shopify = Use FILTER

```liquid
{% comment %} Reading data - result available immediately {% endcomment %}
{% capture query %}
  query { product(id: {{ id | prepend: "gid://shopify/Product/" | json }}) { title } }
{% endcapture %}
{% assign result = query | shopify %}
{% log title: result.data.product.title %}
```

### WRITE to Shopify = Use ACTION

```liquid
{% comment %} Writing data - runs AFTER task completes {% endcomment %}
{% action "shopify" %}
  mutation {
    tagsAdd(id: {{ id | json }}, tags: {{ tags | json }}) {
      userErrors { field message }
    }
  }
{% endaction %}
```

### Email with Placeholders
```liquid
{% assign email_body = options.email__multiline_required
  | replace: "CUSTOMER_NAME", customer.name
  | replace: "ORDER_NUMBER", order.name %}

{% action "email" %}
  {
    "to": {{ email | json }},
    "subject": {{ subject | strip | json }},
    "body": {{ email_body | strip | newline_to_br | json }}
  }
{% endaction %}
```

### Preview Mode
```liquid
{% if event.preview %}
  {% assign order = hash %}
  {% assign order["id"] = "gid://shopify/Order/1234" %}
{% endif %}
```

### Pagination
```liquid
{% for n in (1..100) %}
  {% capture query %}
    query { orders(first: 250, after: {{ cursor | json }}) {
      pageInfo { hasNextPage endCursor }
      nodes { id }
    }}
  {% endcapture %}
  {% assign result = query | shopify %}
  {% if result.data.orders.pageInfo.hasNextPage == false %}{% break %}{% endif %}
  {% assign cursor = result.data.orders.pageInfo.endCursor %}
{% endfor %}
```

### Multi-Recipient Email Loop
```liquid
{% for recipient in options.recipients__email_array_required %}
  {% action "email" %}
    {
      "to": {{ recipient | json }},
      "subject": {{ subject | strip | json }},
      "body": {{ body | strip | newline_to_br | json }}
    }
  {% endaction %}
{% endfor %}
```

### Daily Reset with Cache
```liquid
{% if event.topic == "shopify/orders/create" %}
  {% assign count = cache["daily_count"] | default: 0 | plus: 1 %}
  {% action "cache", "set", "daily_count", count %}
{% elsif event.topic == "mechanic/scheduler/daily" %}
  {% action "cache", "del", "daily_count" %}
{% endif %}
```

### Action Meta for State Tracking (Two-Pass Workflow)
```liquid
{% assign meta = hash %}
{% assign meta["stage"] = "initial" %}
{% action "http", __meta: meta, __perform_event: false %}
  { "method": "post", "url": "..." }
{% endaction %}

{% comment %} Later in mechanic/actions/perform {% endcomment %}
{% if action.meta.stage == "initial" %}
  {% comment %} Handle response {% endcomment %}
{% endif %}
```

## 📝 Option Type Suffixes

**See `mechanic-task-options-reference.md` for complete documentation.**

| Suffix | Type | Example |
| --- | --- | --- |
| `__required` | Required field | `"tag__required": "VIP"` |
| `__number` | Number | `"days__number": 7` |
| `__boolean` | Boolean | `"enabled__boolean": true` |
| `__array` | Array | `"tags__array": ["a", "b"]` |
| `__email` | Email | `"recipient__email": "a@b.com"` |
| `__multiline` | Multi-line text | `"message__multiline": "..."` |
| `__code` | Code editor | `"json__code": "{}"` |
| `__keyval` | Key-value pairs | `"headers__keyval": {"X-Key": "val"}` |
| `__picker_product` | Product picker | GID string |
| `__picker_product_array` | Multi-product picker | Array of GIDs |
| `__picker_collection` | Collection picker | GID string |
| `__select_o1_a_o2_b` | Dropdown | `"mode__select_o1_test_o2_live": "test"` |
| `__multiselect_o1_a_o2_b` | Multi-choice | `["email", "sms"]` |
| `__range_min0_max100` | Slider | `"score__range_min0_max100": 75` |
| `__date` | Date picker | `"2025-05-06"` |
| `__datetime` | Date+time picker | `"2025-05-06T15:30"` |
| `__userform` | Show on Run task form | Any type + userform |

## 🔧 Common Filters

| Filter | Usage | Example |
| --- | --- | --- |
| `shopify` | Execute GraphQL | `query \| shopify` |
| `json` | Convert to JSON | `value \| json` |
| `parse_json` | Parse JSON | `string \| parse_json` |
| `prepend` | Add prefix | `id \| prepend: "gid://..."` |
| `append` | Add suffix | `key \| append: "_suffix"` |
| `replace` | Replace text | `text \| replace: "OLD", "NEW"` |
| `split` | Split string | `"a.b.c" \| split: "."` |
| `where` | Filter array | `items \| where: "status", "active"` |
| `in_groups_of` | Batch array | `items \| in_groups_of: 25` |
| `strip` | Remove whitespace | `text \| strip` |
| `newline_to_br` | Convert newlines | `text \| newline_to_br` |
| `date` | Format date | `"now" \| date: "%Y-%m-%d"` |
| `default` | Fallback value | `var \| default: "none"` |

## 🏷️ GraphQL ID Namespaces

```liquid
{{ product_id | prepend: "gid://shopify/Product/" | json }}
{{ order_id | prepend: "gid://shopify/Order/" | json }}
{{ customer_id | prepend: "gid://shopify/Customer/" | json }}
{{ variant_id | prepend: "gid://shopify/ProductVariant/" | json }}
{{ collection_id | prepend: "gid://shopify/Collection/" | json }}
{{ location_id | prepend: "gid://shopify/Location/" | json }}
```

## 📅 Event Subscriptions

| Type | Example | Description |
| --- | --- | --- |
| Webhook | `shopify/orders/create` | Shopify events |
| Scheduled | `mechanic/scheduler/daily` | Recurring tasks |
| Delayed | `shopify/orders/create+7.days` | Time delays |
| Manual | `mechanic/user/trigger` | Manual run |
| Action | `mechanic/actions/perform` | Chain actions |
| Bulk | `mechanic/shopify/bulk_operation` | Bulk results |

## ⚠️ Common Gotchas

1. **GraphQL IDs need namespace**: Always prepend `gid://shopify/Type/`
2. **Actions execute after task**: Not inline - they run after task completes
3. **250 item page limit**: Always implement pagination
4. **20-second execution limit**: Split large operations
5. **Numbers to strings**: `value | json | remove: '"'` for replacements
6. **Email formatting**: Always `strip` and `newline_to_br`
7. **Preview all paths**: Mock data for every code branch

## 🔍 MCP Commands

```bash
# Search tasks
mcp__mechanic-mcp__search_tasks query:"auto-tag"

# Get task details
mcp__mechanic-mcp__get_task id:"task-handle"

# Find similar
mcp__mechanic-mcp__similar_tasks handle:"task-handle"

# Search docs
mcp__mechanic-mcp__search_docs query:"email"
```

## ✅ Quality Checklist

**Required:**
- [ ] Uses GraphQL not REST
- [ ] Has preview mode data
- [ ] Includes error handling
- [ ] Has logging
- [ ] Proper ID namespaces

**Recommended:**
- [ ] Pagination for large sets
- [ ] Test mode option
- [ ] Caching where beneficial
- [ ] Loop prevention
- [ ] UPPERCASE_PLACEHOLDERS

## 🚀 Testing Commands

```bash
# Validate schema
npm test

# Build documentation
npm run build

# Test in platform
# Use preview mode in Mechanic
```

## 💡 Pro Tips

1. **Search first**: Always check existing tasks before creating new ones
2. **Mock everything**: Preview data should cover all code paths
3. **Log wisely**: Add logs at decision points
4. **Batch operations**: Group API calls when possible
5. **Cache expensive ops**: Store calculated values
6. **Exit early**: Use `{% break %}` to skip unnecessary processing
7. **Validate inputs**: Check options before using
8. **Handle errors**: Check `userErrors` in mutations
9. **Prevent loops**: Check if already processed
10. **Document well**: First paragraph of docs becomes task summary

---

*Keep this reference handy when writing Mechanic tasks!*