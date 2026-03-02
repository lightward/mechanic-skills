# Mechanic Task Options - Complete Reference

## Overview

Task options provide configuration fields for merchants using your tasks. Options are automatically created when you reference `options.something` in your task code. Understanding the sophisticated option system is critical for building professional tasks with great UX.

**Key Concept**: Options use **flags** (tokens after `__`) to control the input type, validation, and behavior.

**CRITICAL**: Option default values in the `options` object MUST be plain values (`null`, `string`, `number`, `boolean`) — never objects with description keys. The option system will handle descriptions separately via flag parsing.

## Quick Examples

```liquid
{{ options.subject }}                                    # Plain text
{{ options.subject__required }}                          # Required text
{{ options.body__multiline }}                            # Multi-line text
{{ options.reply_to__email_required }}                   # Email validation
{{ options.enabled__boolean }}                           # Checkbox
{{ options.count__number }}                              # Numeric input
{{ options.tags__array }}                                # String list
{{ options.headers__keyval }}                            # Key-value map
{{ options.mode__select_o1_test_o2_live }}              # Dropdown
{{ options.channels__multiselect_o1_email_o2_sms }}     # Multi-select checkboxes
{{ options.product__picker_product }}                    # Shopify product picker
{{ options.products__picker_product_array }}            # Multi-product picker
{{ options.launch_date__date }}                          # Date picker
{{ options.send_at__datetime }}                          # Date + time picker
{{ options.score__range_min0_max100 }}                  # Slider (0-100)
{{ options.color__color }}                               # Color picker
```

## Option Naming Rules

```
<name>[__<flag>[_<flag>...]][__<flag>[_<flag>...]...]
```

- **Name**: Lowercase letters, numbers, underscores only
- **Flags**: Customize behavior (separated by `_` within a segment, or by `__` for additional segments)
- Mechanic auto-generates labels from names (underscores become spaces)

**Example**: `notification_email__email_array_required`
- **Name**: `notification_email` → Label: "Notification email"
- **Flags**: `email`, `array`, `required`

## Complete Flag Reference

### Input Type Flags (Choose ONE)

| Flag | UI Control | Value Type | Example |
|------|-----------|------------|---------|
| *(none)* | Single-line text | `string` | `options.subject` |
| `multiline` | Multi-line textarea | `string` | `options.body__multiline` |
| `code` | Code editor | `string` | `options.script__code` |
| `boolean` | Checkbox | `true/false` | `options.enabled__boolean` |
| `number` | Number input | `number` | `options.qty__number` |
| `array` | Value repeater | `array` | `options.tags__array` |
| `keyval` | Key→value repeater | `hash` | `options.headers__keyval` |
| `date` | Calendar picker | `"YYYY-MM-DD"` | `options.launch__date` |
| `datetime` | Date+time picker | `"YYYY-MM-DDTHH:MM"` | `options.send_at__datetime` |
| `time` | Time picker | `"HH:MM"` | `options.quiet_time__time` |
| `color` | Hex color picker | `"#RRGGBB"` | `options.theme__color` |
| `range_minX_maxY` | Slider + number | `number` | `options.score__range_min0_max100` |
| `select` | Dropdown | `string` | `options.mode__select_o1_test_o2_live` |
| `choice` | Radio buttons | `string` | `options.tier__choice_o1_gold_o2_silver` |
| `multiselect` | Checkbox list | `array` | `options.channels__multiselect_o1_email_o2_sms` |
| `picker_<resource>` | Shopify resource picker | `gid string` | `options.product__picker_product` |
| `picker_<resource>_array` | Multi-resource picker | `array[gid]` | `options.products__picker_product_array` |

### Form Modifier Flags (Combine with input types)

| Flag | Effect | Applies To |
|------|--------|------------|
| `required` | Field must be filled | Any |
| `email` | Email validation + placeholder | Text fields |
| `userform` | Show on "Run task" form | Any |

### Auxiliary Flags

| Flag | Works With | Effect |
|------|-----------|--------|
| `futureonly` | `date`, `datetime` | Disallow past dates |

## Advanced Input Types

### Select / Choice / Multiselect - Ordinal Syntax

Use ordinals (`o1`, `o2`, ...) to define choices:

```liquid
{{ options.plan__select_o1_basic_o2_pro_o3_enterprise }}
```

**Breakdown**:
- `select` = dropdown input type
- `o1_basic` = first option with value "basic"
- `o2_pro` = second option with value "pro"
- `o3_enterprise` = third option with value "enterprise"

**Values can include underscores**:
```liquid
{{ options.format__select_o1_json_pretty_o2_json_compact_o3_csv }}
```
Results in choices: "json_pretty", "json_compact", "csv"

**Combining with modifiers**:
```liquid
# RECOMMENDED: Use additional __ segments
{{ options.mode__select_o1_test_o2_live__userform__required }}

# ALSO WORKS: Append to same segment
{{ options.mode__select_o1_test_o2_live_userform_required }}
```

**Avoid using flag words as values**: Don't use "required", "userform", "email" as choice values as they may be parsed as flags.

### Range Sliders

```liquid
{{ options.threshold__range_min0_max100 }}              # 0-100, step 1
{{ options.opacity__range_min0_max100_step5 }}          # 0-100, step 5
{{ options.temperature__range_min-20_max50 }}           # Negative min allowed
```

**Required**: Both `min` and `max` must be specified.
**Optional**: `step` (defaults to 1).

### Shopify Resource Pickers

Pick Shopify resources with native pickers:

```liquid
{{ options.product_to_monitor__picker_product }}
{{ options.variant_to_update__picker_variant }}
{{ options.collection_to_sync__picker_collection }}
```

**Multi-select versions**:
```liquid
{{ options.products_to_tag__picker_product_array }}
{{ options.collections_to_publish__picker_collection_array }}
```

**Supported resources**: `product`, `variant`, `collection`

**Value format**: Global IDs like `"gid://shopify/Product/1234567890"`

**Using in GraphQL**:
```liquid
{% capture query %}
  query {
    product(id: {{ options.product__picker_product__required | json }}) {
      id
      title
    }
  }
{% endcapture %}
{% assign result = query | shopify %}
```

### Key-Value Maps

Perfect for headers, metadata, or configuration:

```liquid
{{ options.http_headers__keyval }}
{{ options.custom_attributes__keyval }}
```

**Returned as hash**:
```json
{
  "X-API-Key": "abc123",
  "X-Environment": "production"
}
```

**Usage**:
```liquid
{% action "http" %}
  {
    "method": "post",
    "url": "https://api.example.com/webhook",
    "headers": {{ options.http_headers__keyval | json }}
  }
{% endaction %}
```

### Array Options

```liquid
{{ options.email_recipients__email_array }}
{{ options.tags_to_add__array }}
```

**Bulk editing**: Arrays with 5+ items show a "Manage in bulk" button, opening a modal where each line = one array element.

**Validation with email**:
```liquid
{{ options.recipients__email_array_required }}
```
Each element must be a valid email address.

## Option Display Order

Options appear in the order they're **first referenced** in task code. Control this with a comment block at the top:

```liquid
{% comment %}
  Option order:

  {{ options.api_key__required }}
  {{ options.api_secret__required }}
  {{ options.mode__select_o1_test_o2_live }}
  {{ options.notification_email__email }}
  {{ options.enabled__boolean }}
{% endcomment %}

{% comment %} Rest of your task code {% endcomment %}
```

This ensures options appear in a logical sequence for merchants.

## Custom Validation

Beyond built-in validation, add custom rules with the `{% error %}` tag:

```liquid
{% if options.minimum_value__number_required <= 0 %}
  {% error "'Minimum value' must be greater than zero." %}
{% endif %}

{% if options.value_a__number == options.value_b__number %}
  {% error "'Value A' and 'Value B' must be different." %}
{% endif %}

{% if options.email_subject__required contains "PLACEHOLDER" %}
  {% error "Please replace PLACEHOLDER in the email subject." %}
{% endif %}
```

Errors appear during preview, preventing task save until resolved.

## Liquid Evaluation in Options

Options support Liquid evaluation **before** task code runs:

```liquid
{{ options.shop_name }}
# Merchant can enter: {{ shop.name }}'s Store
# At runtime, becomes: "My Shop's Store"
```

**Available variables**: `event`, `shop`, `cache`, and event subject variables (e.g., `order`, `product`).

**Not available**: Variables created in task code (they don't exist yet).

## User Form Fields

Options flagged with `__userform` appear on the "Run task" form and Shopify admin action links:

```liquid
{{ options.order_tags__array_userform }}
{{ options.note__multiline_userform }}
{{ options.mode__select_o1_test_o2_live__userform__required }}
```

**Access submitted values** with `input.<name>`:
```liquid
{% if event.topic == "mechanic/user/form" %}
  {% assign submitted_tags = input.order_tags %}
  {% log user_submitted: submitted_tags %}
{% endif %}
```

## Working with Date/Time Options

### Formatting

```liquid
{% assign launch = options.launch_date__date %}
{{ launch | date: "%Y-%m-%d" }}
# => 2025-05-06

{% assign party = options.party__datetime %}
{{ party | date: "%Y-%m-%d at %H:%M" }}
# => 2031-04-22 at 15:13
```

### Timezone Conversion

```liquid
{{ options.send_at__datetime | date: "%s", tz: "UTC" }}
# => Unix timestamp in UTC

{{ options.send_at__datetime | date: "%Y-%m-%d %H:%M %Z", tz: "America/Vancouver" }}
# => 2025-05-06 21:25 PDT
```

### Future-only Dates

```liquid
{{ options.go_live_date__date_futureonly }}
```
Date picker disallows past dates.

## Complete Examples

### Example 1: Product Tagging Task

```liquid
{% comment %}
  Option order:

  {{ options.product_to_tag__picker_product__required }}
  {{ options.tags_to_add__array_required }}
  {{ options.remove_existing_tags__boolean }}
  {{ options.test_mode__boolean }}
{% endcomment %}

{% if options.tags_to_add__array_required == blank %}
  {% error "At least one tag is required." %}
{% endif %}

{% assign product_id = options.product_to_tag__picker_product__required %}

{% action "shopify" %}
  mutation {
    tagsAdd(
      id: {{ product_id | json }}
      tags: {{ options.tags_to_add__array_required | json }}
    ) {
      userErrors { field message }
    }
  }
{% endaction %}
```

### Example 2: Scheduled Email with Multi-Recipients

```liquid
{% comment %}
  Option order:

  {{ options.recipients__email_array_required }}
  {{ options.subject__required }}
  {{ options.body__multiline_required }}
  {{ options.send_at__datetime_futureonly }}
  {{ options.include_attachment__boolean }}
{% endcomment %}

{% for recipient in options.recipients__email_array_required %}
  {% action "email" %}
    {
      "to": {{ recipient | json }},
      "subject": {{ options.subject__required | json }},
      "body": {{ options.body__multiline_required | strip | newline_to_br | json }},
      "reply_to": {{ shop.customer_email | json }}
    }
  {% endaction %}
{% endfor %}
```

### Example 3: Advanced Configuration Task

```liquid
{% comment %}
  Option order:

  {{ options.api_endpoint__required }}
  {{ options.http_headers__keyval }}
  {{ options.retry_count__range_min1_max10 }}
  {{ options.mode__select_o1_test_o2_production__required }}
  {{ options.notification_emails__email_array }}
  {{ options.enable_debug_logging__boolean }}
{% endcomment %}

{% assign headers = options.http_headers__keyval | default: hash %}

{% action "http" %}
  {
    "method": "post",
    "url": {{ options.api_endpoint__required | json }},
    "headers": {{ headers | json }}
  }
{% endaction %}
```

### Example 4: Daily Limit with Threshold

```liquid
{% comment %}
  Option order:

  {{ options.maximum_daily_orders__number_required }}
  {{ options.alert_threshold__range_min50_max95 }}
  {{ options.notification_emails__email_array_required }}
  {{ options.email_subject__required }}
  {{ options.email_body__multiline_required }}
{% endcomment %}

{% if options.maximum_daily_orders__number_required <= 0 %}
  {% error "'Maximum daily orders' must be at least 1." %}
{% endif %}

{% if options.alert_threshold__range_min50_max95 %}
  {% assign threshold = options.alert_threshold__range_min50_max95 %}
{% else %}
  {% assign threshold = 80 %}
{% endif %}

{% assign threshold_count = options.maximum_daily_orders__number_required | times: threshold | divided_by: 100.0 | ceil %}

{% log
  message: "Alert threshold calculated",
  threshold_percentage: threshold,
  threshold_count: threshold_count
%}
```

## Quick Reference Table

| Goal | Example Key | Value Type | UI Control |
|------|------------|------------|-----------|
| Plain text | `options.note` | `string` | Text input |
| Required text | `options.subject__required` | `string` | Text input |
| Email | `options.reply_to__email_required` | `string` | Email input |
| Multi-line | `options.body__multiline` | `string` | Textarea |
| Checkbox | `options.enabled__boolean` | `boolean` | Checkbox |
| Number | `options.count__number` | `number` | Number input |
| String list | `options.tags__array` | `array` | Repeater |
| Email list | `options.recipients__email_array` | `array` | Repeater |
| Key-value | `options.headers__keyval` | `hash` | Repeater |
| Dropdown | `options.mode__select_o1_a_o2_b` | `string` | Select |
| Multi-choice | `options.opts__multiselect_o1_a_o2_b` | `array` | Checkboxes |
| Slider | `options.score__range_min0_max100` | `number` | Slider |
| Color | `options.theme__color` | `string` | Color picker |
| Date | `options.launch__date` | `string` | Date picker |
| DateTime | `options.send_at__datetime` | `string` | DateTime picker |
| Product picker | `options.product__picker_product` | `string` | Picker |
| Product list | `options.products__picker_product_array` | `array` | Picker |
| Run task field | `options.note__userform` | `string` | Text input |

## Best Practices

1. **Always use required for critical options**: `__required` prevents merchant confusion
2. **Group related options logically**: Use option order comment block
3. **Provide sensible defaults**: Use `| default: value` in code
4. **Validate early**: Add custom validation at the top of your task
5. **Use specific types**: `__email_array` is better than just `__array`
6. **Use pickers for Shopify resources**: Better UX than asking merchants to paste IDs
7. **Document complex options**: Use task docs to explain what each option does
8. **Use userform sparingly**: Only for options needed at run time
9. **Test all edge cases**: Empty arrays, zero values, missing optionals

## Common Patterns

### Multi-Recipient Email Loop

```liquid
{% for recipient in options.recipients__email_array_required %}
  {% action "email" %}
    {
      "to": {{ recipient | json }},
      "subject": {{ subject | json }},
      "body": {{ body | json }}
    }
  {% endaction %}
{% endfor %}
```

### Conditional Features

```liquid
{% if options.enable_advanced_mode__boolean %}
  {% comment %} Advanced logic {% endcomment %}
{% else %}
  {% comment %} Simple logic {% endcomment %}
{% endif %}
```

### Test Mode with Logging

```liquid
{% if options.test_mode__boolean %}
  {% log
    message: "TEST MODE: Would perform action",
    action_data: action_data
  %}
{% else %}
  {% action "shopify" %}
    {% comment %} Real mutation {% endcomment %}
  {% endaction %}
{% endif %}
```

### Resource Picker Validation

```liquid
{% if options.product__picker_product__required == blank %}
  {% error "Please select a product." %}
{% endif %}
```

## Troubleshooting

**Problem**: Option not appearing in UI
- **Solution**: Reference it at least once in task code (even in a comment)

**Problem**: Options appearing in wrong order
- **Solution**: Add option order comment block at top of task

**Problem**: Choice values contain underscores but getting parsed as flags
- **Solution**: Underscores within ordinal values are preserved (`o1_my_value` → `"my_value"`)

**Problem**: Custom validation not showing
- **Solution**: Validation only runs during preview - check preview pane for errors

**Problem**: Liquid in option not evaluating
- **Solution**: Ensure you're referencing available variables (`shop`, `event`, etc.), not task code variables

**Problem**: Array option too long to manage
- **Solution**: Use the "Manage in bulk" button (appears automatically at 5+ items)

## Resources

- **Official docs**: https://learn.mechanic.dev/core/tasks/options
- **Custom validation**: https://learn.mechanic.dev/core/tasks/options/custom-validation
- **User form**: https://learn.mechanic.dev/core/tasks/user-form
- **Environment variables**: https://learn.mechanic.dev/core/tasks/code/environment-variables
