# Mechanic Patterns: Advanced Techniques

Production-proven patterns from analyzing 359+ tasks in the Mechanic task library.

## Pattern: Daily Reset with Cache

Track daily counts or states with automatic midnight reset. Common for order limits, daily reports, and recurring notifications.

### Implementation

```liquid
{% comment %}
  Option order:

  {{ options.maximum_daily_orders__number_required }}
  {{ options.notification_email__email_required }}
{% endcomment %}

{% assign cache_key = "daily_count:" | append: task.id %}
{% assign count_today = cache[cache_key] | default: 0 %}

{% if event.topic == "shopify/orders/create" %}
  {% comment %} Increment counter {% endcomment %}
  {% assign count_today = count_today | plus: 1 %}
  {% action "cache", "set", cache_key, count_today %}

  {% if count_today >= options.maximum_daily_orders__number_required %}
    {% action "email" %}
      {
        "to": {{ options.notification_email__email_required | json }},
        "subject": "Daily limit reached: {{ count_today }} orders",
        "body": "Your store has reached the daily order limit."
      }
    {% endaction %}
  {% endif %}

{% elsif event.topic == "mechanic/scheduler/daily" %}
  {% comment %} Reset counter at midnight {% endcomment %}
  {% action "cache", "del", cache_key %}
  {% log message: "Daily counter reset", cache_key: cache_key %}
{% endif %}
```

### Key Subscriptions

```json
[
  "shopify/orders/create",
  "mechanic/scheduler/daily"
]
```

### Why It Works

- Cache persists between task runs
- `mechanic/scheduler/daily` runs at midnight in shop timezone
- Deleting cache key resets count to 0 (via `| default: 0`)
- No database queries needed - pure cache-based

### Variations

**Alert only once per day:**
```liquid
{% assign alert_sent_key = "alert_sent:" | append: task.id %}
{% assign alert_already_sent = cache[alert_sent_key] | default: false %}

{% if count_today >= limit and alert_already_sent == false %}
  {% action "email" %}...{% endaction %}
  {% action "cache", "set", alert_sent_key, true %}
{% endif %}
```

**Track multiple metrics:**
```liquid
{% assign orders_key = "daily_orders:" | append: task.id %}
{% assign revenue_key = "daily_revenue:" | append: task.id %}

{% assign orders_today = cache[orders_key] | default: 0 | plus: 1 %}
{% assign revenue_today = cache[revenue_key] | default: 0 | plus: order.totalPriceSet.shopMoney.amount %}

{% action "cache", "set", orders_key, orders_today %}
{% action "cache", "set", revenue_key, revenue_today %}
```

---

## Pattern: Manual Status Reports

Provide on-demand reports using `mechanic/user/trigger`.

### Implementation

```liquid
{% assign previous_midnight = "now" | date: "%Y-%m-%dT00:00:00%z" %}

{% if event.topic == "mechanic/user/trigger" or event.preview %}
  {% comment %} Query for today's orders {% endcomment %}
  {% capture query %}
    query {
      orders(
        first: 250
        query: "created_at:>={{ previous_midnight | json }}"
      ) {
        nodes {
          id
          name
          totalPriceSet {
            shopMoney {
              amount
              currencyCode
            }
          }
        }
      }
    }
  {% endcapture %}

  {% assign result = query | shopify %}

  {% if event.preview %}
    {% capture result_json %}
      {
        "data": {
          "orders": {
            "nodes": [
              {
                "id": "gid://shopify/Order/1234567890",
                "name": "#1001",
                "totalPriceSet": {
                  "shopMoney": {
                    "amount": "99.99",
                    "currencyCode": "USD"
                  }
                }
              }
            ]
          }
        }
      }
    {% endcapture %}
    {% assign result = result_json | parse_json %}
  {% endif %}

  {% assign orders = result.data.orders.nodes %}
  {% assign total_revenue = 0 %}

  {% for order in orders %}
    {% assign total_revenue = total_revenue | plus: order.totalPriceSet.shopMoney.amount %}
  {% endfor %}

  {% capture report_html %}
    <h2>Daily Status Report</h2>
    <p><strong>Report time:</strong> {{ "now" | date: "%Y-%m-%d %H:%M %Z" }}</p>
    <p><strong>Orders today:</strong> {{ orders.size }}</p>
    <p><strong>Total revenue:</strong> ${{ total_revenue }}</p>

    <h3>Recent Orders</h3>
    <ul>
      {% for order in orders limit: 10 %}
        <li>{{ order.name }} - ${{ order.totalPriceSet.shopMoney.amount }}</li>
      {% endfor %}
    </ul>
  {% endcapture %}

  {% action "email" %}
    {
      "to": {{ shop.email | json }},
      "subject": "Daily Status Report - {{ orders.size }} orders",
      "body": {{ report_html | json }},
      "from_display_name": {{ shop.name | json }}
    }
  {% endaction %}
{% endif %}
```

### Key Subscriptions

```json
[
  "mechanic/user/trigger"
]
```

### Why It Works

- Runs when merchant clicks "Run task" button
- Provides immediate feedback
- Perfect for ad-hoc reports
- No scheduled runs needed

### Usage Tips

- Combine with `mechanic/scheduler/daily` for automated + on-demand reports
- Add date range options for flexible reporting
- Include current cache state for debugging

---

## Pattern: Multi-Recipient Email Loops

Send emails to multiple recipients from an array option.

### Implementation

```liquid
{% comment %}
  Option order:

  {{ options.notification_recipients__email_array_required }}
  {{ options.email_subject__required }}
  {{ options.email_body__multiline_required }}
{% endcomment %}

{% if options.notification_recipients__email_array_required == blank %}
  {% error "At least one notification recipient is required." %}
{% endif %}

{% assign subject = options.email_subject__required %}
{% assign body = options.email_body__multiline_required %}

{% comment %} Loop through all recipients {% endcomment %}
{% for recipient in options.notification_recipients__email_array_required %}
  {% action "email" %}
    {
      "to": {{ recipient | json }},
      "subject": {{ subject | strip | json }},
      "body": {{ body | strip | newline_to_br | json }},
      "from_display_name": {{ shop.name | json }},
      "reply_to": {{ shop.customer_email | json }}
    }
  {% endaction %}
{% endfor %}

{% if event.preview %}
  {% log
    message: "[PREVIEW] Emails would be queued",
    recipient_count: options.notification_recipients__email_array_required.size,
    recipients: options.notification_recipients__email_array_required
  %}
{% else %}
  {% log
    message: "Emails queued",
    recipient_count: options.notification_recipients__email_array_required.size,
    recipients: options.notification_recipients__email_array_required
  %}
{% endif %}
```

### Why It Works

- Each recipient gets their own email action
- Actions run independently (if one fails, others still send)
- Logging tracks how many emails sent

### Best Practices

- Always validate array is not empty
- Log recipient count for debugging
- Use `strip` on subject and `newline_to_br` on body
- Set appropriate `from_display_name` and `reply_to`

---

## Pattern: Dynamic Shopify Query Building

Build flexible search queries from options.

### Implementation

```liquid
{% comment %}
  Option order:

  {{ options.minimum_order_value__number }}
  {{ options.exclude_cancelled_orders__boolean }}
  {{ options.only_paid_orders__boolean }}
  {{ options.tags_to_include__array }}
{% endcomment %}

{% assign previous_midnight = "now" | date: "%Y-%m-%dT00:00:00%z" %}

{% comment %} Build dynamic query {% endcomment %}
{% capture orders_query %}
  created_at:>={{ previous_midnight | json }}
{% endcapture %}

{% if options.minimum_order_value__number %}
  {% capture orders_query %}
    {{ orders_query }} total_price:>={{ options.minimum_order_value__number }}
  {% endcapture %}
{% endif %}

{% if options.exclude_cancelled_orders__boolean %}
  {% capture orders_query %}
    {{ orders_query }} -status:cancelled
  {% endcapture %}
{% endif %}

{% if options.only_paid_orders__boolean %}
  {% capture orders_query %}
    {{ orders_query }} financial_status:paid
  {% endcapture %}
{% endif %}

{% if options.tags_to_include__array != blank %}
  {% for tag in options.tags_to_include__array %}
    {% capture orders_query %}
      {{ orders_query }} tag:{{ tag | json }}
    {% endcapture %}
  {% endfor %}
{% endif %}

{% assign orders_query = orders_query | strip %}

{% log constructed_query: orders_query %}

{% capture query %}
  query {
    orders(
      first: 250
      query: {{ orders_query | json }}
    ) {
      nodes {
        id
        name
      }
    }
  }
{% endcapture %}

{% assign result = query | shopify %}
```

### Why It Works

- Builds query string dynamically based on configuration
- Uses Shopify's search syntax
- Logs final query for debugging
- Allows flexible filtering without code changes

### Common Query Operators

- `created_at:>="2025-01-01"`
- `total_price:>=100`
- `-status:cancelled` (exclude)
- `financial_status:paid`
- `tag:"vip"`
- `email:"customer@example.com"`

---

## Pattern: Percentage Threshold Calculations

Calculate threshold values from percentages.

### Implementation

```liquid
{% comment %}
  Option order:

  {{ options.maximum_daily_orders__number_required }}
  {{ options.alert_at_percentage__range_min50_max95 }}
  {{ options.notification_email__email_required }}
{% endcomment %}

{% assign max_orders = options.maximum_daily_orders__number_required %}
{% assign alert_percentage = options.alert_at_percentage__range_min50_max95 | default: 80 %}

{% comment %} Calculate threshold count {% endcomment %}
{% assign threshold_count = max_orders | times: alert_percentage | divided_by: 100.0 | ceil %}

{% log
  message: "Threshold calculated",
  max_orders: max_orders,
  alert_percentage: alert_percentage,
  threshold_count: threshold_count,
  percentage_of_max: alert_percentage
%}

{% assign orders_today = 15 %}  {% comment %} From your counting logic {% endcomment %}
{% assign current_percentage = orders_today | times: 100.0 | divided_by: max_orders %}

{% if orders_today >= threshold_count %}
  {% action "email" %}
    {
      "to": {{ options.notification_email__email_required | json }},
      "subject": "Alert: {{ current_percentage | round: 1 }}% of daily limit reached",
      "body": "{{ orders_today }} of {{ max_orders }} orders ({{ current_percentage | round: 1 }}% of limit)"
    }
  {% endaction %}
{% endif %}
```

### Key Techniques

- `times: percentage | divided_by: 100.0` for percentage calculation
- `ceil` rounds up to ensure threshold is met
- `.0` forces float division for accuracy
- `round: 1` for clean display

---

## Pattern: Cache-Based Alert Throttling

Send alerts only once per condition, not on every occurrence.

### Implementation

```liquid
{% assign alert_key = "alert_sent:" | append: condition_fingerprint %}
{% assign alert_sent = cache[alert_key] | default: false %}

{% if condition_met and alert_sent == false %}
  {% action "email" %}
    {
      "to": {{ recipient | json }},
      "subject": "Alert: Condition detected",
      "body": "This alert will only be sent once until condition clears."
    }
  {% endaction %}

  {% comment %} Mark alert as sent {% endcomment %}
  {% action "cache", "set", alert_key, true %}

  {% log message: "Alert sent and cached", alert_key: alert_key %}
{% elsif alert_sent %}
  {% log message: "Alert already sent, skipping", alert_key: alert_key %}
{% endif %}

{% comment %} Clear alert cache when condition resolves {% endcomment %}
{% unless condition_met %}
  {% if alert_sent %}
    {% action "cache", "del", alert_key %}
    {% log message: "Condition cleared, alert cache reset" %}
  {% endif %}
{% endunless %}
```

### Variations

**Time-based throttling:**
```liquid
{% assign last_alert = cache["last_alert"] %}
{% assign current_time = "now" | date: "%s" %}
{% assign time_since_alert = current_time | minus: last_alert %}

{% if time_since_alert >= 3600 %}  {% comment %} 1 hour {% endcomment %}
  {% action "email" %}...{% endaction %}
  {% action "cache", "set", "last_alert", current_time %}
{% endif %}
```

**Alert threshold escalation:**
```liquid
{% assign alert_count = cache["alert_count"] | default: 0 | plus: 1 %}
{% action "cache", "set", "alert_count", alert_count %}

{% assign thresholds = "1,10,25,50,100" | split: "," %}
{% if thresholds contains alert_count %}
  {% action "email" %}
    {
      "subject": "Alert #{{ alert_count }}: Issue still occurring"
    }
  {% endaction %}
{% endif %}
```

---

## Pattern: Future Event Scheduling

Schedule events for specific times using `run_at`.

### Implementation

```liquid
{% comment %} Schedule email for 7 days from now {% endcomment %}
{% assign seven_days_later = "now" | date: "%s", advance: "7 days" %}

{% action "event" %}
  {
    "topic": "user/followup/email",
    "data": {
      "order_id": {{ order.id | json }},
      "customer_email": {{ order.email | json }}
    },
    "run_at": {{ seven_days_later | json }},
    "task_id": {{ task.id | json }}
  }
{% endaction %}
```

### Advanced Scheduling

**Schedule at specific time:**
```liquid
{% comment %} Schedule for next Monday at 9 AM {% endcomment %}
{% assign next_monday = "now" | date: "%s", advance: "1 week" %}
{% assign next_monday_9am = next_monday | date: "%Y-%m-%d", tz: shop.timezone | append: "T09:00:00" %}

{% action "event" %}
  {
    "topic": "user/weekly/report",
    "run_at": {{ next_monday_9am | date: "%s", tz: shop.timezone | json }}
  }
{% endaction %}
```

**Schedule with option:**
```liquid
{% assign delay_days = options.followup_delay_days__number_required | default: 7 %}
{% assign followup_time = "now" | date: "%s", advance: delay_days, unit: "days" %}

{% action "event" %}
  {
    "topic": "user/followup",
    "data": {{ followup_data | json }},
    "run_at": {{ followup_time | json }}
  }
{% endaction %}
```

### Responding to Scheduled Events

```liquid
{% if event.topic == "shopify/orders/create" %}
  {% comment %} Schedule followup {% endcomment %}
  {% action "event" %}...{% endaction %}

{% elsif event.topic == "user/followup/email" %}
  {% comment %} Process scheduled event {% endcomment %}
  {% assign order_id = event.data.order_id %}
  {% assign customer_email = event.data.customer_email %}

  {% if event.preview %}
    {% log
      message: "[PREVIEW] Follow-up email would be sent",
      customer_email: customer_email,
      order_id: order_id
    %}
  {% else %}
    {% action "email" %}
      {
        "to": {{ customer_email | json }},
        "subject": "Following up on your order"
      }
    {% endaction %}
  {% endif %}
{% endif %}
```

---

## Pattern: Debouncing Rapid Events

Prevent rapid-fire event processing using cache timestamps.

### Implementation

```liquid
{% assign debounce_key = "last_run:" | append: product.id %}
{% assign last_run = cache[debounce_key] %}
{% assign current_time = "now" | date: "%s" %}

{% if last_run %}
  {% assign time_since_last_run = current_time | minus: last_run %}
  {% if time_since_last_run < 300 %}  {% comment %} 5 minutes {% endcomment %}
    {% log
      message: "Debouncing: ran too recently",
      seconds_since_last_run: time_since_last_run,
      will_skip: true
    %}
    {% break %}
  {% endif %}
{% endif %}

{% comment %} Process event {% endcomment %}
{% action "shopify" %}
  mutation {
    productUpdate(input: { id: {{ product.id | json }}, tags: ["processed"] }) {
      userErrors { field message }
    }
  }
{% endaction %}

{% comment %} Update last run time {% endcomment %}
{% action "cache", "set", debounce_key, current_time %}
```

### Why Debouncing Matters

- Shopify can send multiple update events in quick succession
- Prevents duplicate processing
- Reduces API calls
- Avoids action loops

### Configurable Debounce Window

```liquid
{% assign debounce_seconds = options.debounce_window_seconds__number | default: 300 %}

{% if time_since_last_run < debounce_seconds %}
  {% break %}
{% endif %}
```

---

## Pattern: Batch Processing with Delay Preference

Choose between delayed subscriptions and batch processing.

### Approach 1: Delayed Subscription (Simple)

```json
{
  "subscriptions": [
    "shopify/orders/create+7.days"
  ]
}
```

**Pros**: Simple, automatic scheduling
**Cons**: Events pile up, can't cancel if task disabled

### Approach 2: Daily Batch (Recommended)

```liquid
{% if event.topic == "mechanic/scheduler/daily" or event.preview %}
  {% assign seven_days_ago = "now" | date: "%s", advance: -7, unit: "days" %}
  {% assign seven_days_ago_date = seven_days_ago | date: "%Y-%m-%d" %}

  {% capture query %}
    query {
      orders(
        first: 250
        query: "created_at:{{ seven_days_ago_date }}"
      ) {
        nodes {
          id
          email
          name
        }
      }
    }
  {% endcapture %}

  {% assign result = query | shopify %}

  {% if event.preview %}
    {% assign result_json %}
      {
        "data": {
          "orders": {
            "nodes": [
              {
                "id": "gid://shopify/Order/1234567890",
                "email": "customer@example.com",
                "name": "#1001"
              }
            ]
          }
        }
      }
    {% endassign %}
    {% assign result = result_json | parse_json %}
    {% log message: "[PREVIEW] Would process {{ result.data.orders.nodes.size }} orders for batch email" %}
  {% endif %}

  {% for order in result.data.orders.nodes %}
    {% if event.preview %}
      {% log
        message: "[PREVIEW] Email would be sent",
        to: order.email,
        order_name: order.name
      %}
    {% else %}
      {% action "email" %}
        {
          "to": {{ order.email | json }},
          "subject": "Thanks for your order {{ order.name }}"
        }
      {% endaction %}
    {% endif %}
  {% endfor %}
{% endif %}
```

**Pros**:
- Can disable task anytime
- Processes all eligible orders in batch
- No queued events to worry about
- Immediately active when enabled

**Cons**: Slightly more complex code

---

## Pattern: Progressive State Management

Track multi-stage workflows with action meta.

### Implementation

```liquid
{% if event.topic == "shopify/orders/create" or event.preview %}
  {% comment %} Stage 1: Initiate workflow {% endcomment %}
  {% assign meta = hash %}
  {% assign meta["stage"] = "initiated" %}
  {% assign meta["order_id"] = order.id %}

  {% if event.preview %}
    {% log
      message: "[PREVIEW] Verification request would be initiated",
      order_id: order.id
    %}
  {% else %}
    {% action "http", __meta: meta %}
      {
        "method": "post",
        "url": "https://api.example.com/verify",
        "body": {{ order | json }}
      }
    {% endaction %}
  {% endif %}

{% elsif event.topic == "mechanic/actions/perform" %}
  {% if action.type == "http" and action.meta.stage == "initiated" %}
    {% comment %} Stage 2: Process response {% endcomment %}
    {% if action.run.ok %}
      {% assign verification_result = action.run.response.body | parse_json %}

      {% if verification_result.approved %}
        {% comment %} Stage 3: Finalize {% endcomment %}
        {% action "shopify", __perform_event: false %}
          mutation {
            tagsAdd(
              id: {{ action.meta.order_id | json }}
              tags: ["verified"]
            ) {
              userErrors { field message }
            }
          }
        {% endaction %}
      {% endif %}
    {% endif %}
  {% endif %}
{% endif %}
```

### Key Techniques

- Use `action.meta` to pass state between stages
- Check `action.type` and `action.meta.stage` to route logic
- Subscribe to `mechanic/actions/perform` to handle action results

---

## Pattern: Complex Validation with Multiple Checks

Validate multiple conditions with clear error messages.

### Implementation

```liquid
{% assign errors = array %}

{% if options.minimum_value__number_required <= 0 %}
  {% assign errors = errors | push: "'Minimum value' must be greater than zero." %}
{% endif %}

{% if options.maximum_value__number_required <= options.minimum_value__number_required %}
  {% assign errors = errors | push: "'Maximum value' must be greater than 'Minimum value'." %}
{% endif %}

{% if options.notification_emails__email_array_required == blank %}
  {% assign errors = errors | push: "At least one notification email is required." %}
{% endif %}

{% if options.product__picker_product == blank and options.collection__picker_collection == blank %}
  {% assign errors = errors | push: "Please select either a product or a collection." %}
{% endif %}

{% if errors.size > 0 %}
  {% assign error_message = errors | join: " " %}
  {% error error_message %}
{% endif %}
```

### Benefits

- All validation errors shown at once
- Clear, specific error messages
- Easy to maintain and extend

---

## Quick Reference: Common Advanced Patterns

| Pattern | Use Case | Key Techniques |
|---------|----------|----------------|
| Daily Reset | Order limits, daily reports | Cache + scheduler/daily |
| Status Reports | On-demand info | mechanic/user/trigger |
| Multi-Recipient | Alert multiple people | Loop over email array |
| Query Building | Flexible filtering | Dynamic string construction |
| Threshold Calc | Percentage alerts | times/divided_by with .0 |
| Alert Throttling | Prevent spam | Cache boolean flags |
| Event Scheduling | Delayed actions | action "event" with run_at |
| Debouncing | Prevent duplicates | Cache timestamps |
| Batch Processing | Daily workflows | scheduler vs delayed subs |
| State Management | Multi-stage flows | action.meta |

## Resources

- **Official docs**: https://learn.mechanic.dev
- **Task library**: https://tasks.mechanic.dev (359+ production examples)
- **Cache documentation**: https://learn.mechanic.dev/platform/cache
- **Event scheduling**: https://learn.mechanic.dev/core/actions/event
