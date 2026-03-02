# Mechanic Patterns: Email Communications

## Pattern: Basic Email with Placeholder Variables

The most common email pattern - customizable templates with variable replacement:

```liquid
{% comment %} Define email template with placeholders {% endcomment %}
{% assign email_subject = options.email_subject__required | default: "Order ORDER_NUMBER confirmed" %}
{% assign email_body = options.email_body__multiline_required | default: "Hi CUSTOMER_NAME,\n\nYour order is confirmed!\n\nThanks,\n{{ shop.name }}" %}

{% comment %} Convert numbers to strings for replacement {% endcomment %}
{% assign order_total_string = order.totalPriceSet.shopMoney.amount | json | remove: '"' %}

{% comment %} Replace placeholders with actual values {% endcomment %}
{% assign email_subject = email_subject | replace: "ORDER_NUMBER", order.name | replace: "ORDER_TOTAL", order_total_string %}
{% assign email_body = email_body | replace: "ORDER_NUMBER", order.name | replace: "CUSTOMER_NAME", order.customer.firstName | default: "there" | replace: "ORDER_TOTAL", order_total_string %}

{% comment %} Send the email {% endcomment %}
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

## Pattern: Email with PDF Attachment

Generate and attach PDF invoices or reports:

```liquid
{% capture invoice_html %}
  <h1>Invoice {{ order.name }}</h1>
  <p>Date: {{ order.createdAt | date: "%B %d, %Y" }}</p>

  <table>
    <tr><th>Item</th><th>Qty</th><th>Price</th></tr>
    {% for line in order.lineItems.nodes %}
      <tr>
        <td>{{ line.title }}</td>
        <td>{{ line.quantity }}</td>
        <td>{{ line.originalTotalSet.shopMoney.amount | currency }}</td>
      </tr>
    {% endfor %}
  </table>

  <p><strong>Total: {{ order.totalPriceSet.shopMoney.amount | currency }}</strong></p>
{% endcapture %}

{% action "email" %}
  {
    "to": {{ customer.email | json }},
    "subject": "Invoice for order {{ order.name }}",
    "body": "Please find your invoice attached.",
    "attachments": {
      "invoice-{{ order.name }}.pdf": {
        "pdf": {
          "html": {{ invoice_html | json }}
        }
      }
    }
  }
{% endaction %}
```

## Pattern: Conditional Email Notifications

Send different emails based on conditions:

```liquid
{% comment %} Determine which email to send {% endcomment %}
{% if order.customer == nil %}
  {% assign recipient = options.guest_notification_email__email %}
  {% assign subject = "Guest order received" %}
{% elsif order.customer.tags contains "vip" %}
  {% assign recipient = order.customer.email %}
  {% assign subject = "VIP order confirmed - Priority processing" %}
{% else %}
  {% assign recipient = order.customer.email %}
  {% assign subject = "Order confirmed" %}
{% endif %}

{% comment %} Only send if we have a recipient {% endcomment %}
{% if recipient %}
  {% action "email" %}
    {
      "to": {{ recipient | json }},
      "subject": {{ subject | json }},
      "body": "Order {{ order.name }} has been received and is being processed.",
      "from_display_name": {{ shop.name | json }}
    }
  {% endaction %}
{% endif %}
```

## Pattern: Batch Email with CSV Report

Send periodic reports to administrators:

```liquid
{% comment %} Build CSV data {% endcomment %}
{% assign csv_rows = array %}
{% assign header = array %}
{% assign header[0] = "Product" %}
{% assign header[1] = "SKU" %}
{% assign header[2] = "Inventory" %}
{% assign csv_rows[0] = header %}

{% for product in products %}
  {% for variant in product.variants.nodes %}
    {% if variant.inventoryQuantity < 10 %}
      {% assign row = array %}
      {% assign row[0] = product.title %}
      {% assign row[1] = variant.sku %}
      {% assign row[2] = variant.inventoryQuantity %}
      {% assign csv_rows[csv_rows.size] = row %}
    {% endif %}
  {% endfor %}
{% endfor %}

{% comment %} Send email with CSV attachment {% endcomment %}
{% if csv_rows.size > 1 %}
  {% action "email" %}
    {
      "to": {{ options.admin_email__email_required | json }},
      "subject": "Low inventory report - {{ "now" | date: "%B %d, %Y" }}",
      "body": "{{ csv_rows.size | minus: 1 }} items are low on inventory. See attached report.",
      "attachments": {
        "low-inventory.csv": {{ csv_rows | csv | json }}
      }
    }
  {% endaction %}
{% endif %}
```

## Pattern: Multi-recipient Notifications (Individual Emails)

**Recommended approach**: Send individual emails to each recipient from email array option.

```liquid
{% comment %}
  Option:
  {{ options.notification_recipients__email_array_required }}
{% endcomment %}

{% if options.notification_recipients__email_array_required == blank %}
  {% error "At least one notification recipient is required." %}
{% endif %}

{% assign subject = "Daily sales summary" %}
{% assign body = "Today's sales: {{ daily_total | currency }}" %}

{% comment %} Loop through all recipients {% endcomment %}
{% for recipient in options.notification_recipients__email_array_required %}
  {% log
    message: "Sending notification email",
    recipient: recipient,
    loop_index: forloop.index,
    total_recipients: options.notification_recipients__email_array_required.size
  %}

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

{% log
  message: "All notification emails queued",
  recipient_count: options.notification_recipients__email_array_required.size
%}
```

**Why individual emails?**
- Each recipient gets their own action run
- If one fails, others still send
- Better deliverability tracking
- Can personalize per recipient if needed

## Pattern: Multi-recipient with BCC

Alternative approach using BCC for group notifications:

```liquid
{% assign notification_emails = options.notification_emails__email_array_required %}
{% assign primary_recipient = notification_emails[0] %}
{% assign bcc_recipients = notification_emails | slice: 1, notification_emails.size %}

{% action "email" %}
  {
    "to": {{ primary_recipient | json }},
    "bcc": {{ bcc_recipients | json }},
    "subject": "Daily sales summary",
    "body": "Today's sales: {{ daily_total | currency }}",
    "from_display_name": {{ shop.name | json }}
  }
{% endaction %}
```

**Use BCC when**: You want recipients to not see each other's addresses (privacy).

## Pattern: Email with Placeholder Template

Production pattern from 80%+ of email tasks:

```liquid
{% comment %}
  Options:
  {{ options.email_subject__required }}
  {{ options.email_body__multiline_required }}
{% endcomment %}

{% comment %} Convert numbers to strings for replacement {% endcomment %}
{% assign order_total_string = order.totalPriceSet.shopMoney.amount | json | remove: '"' %}
{% assign item_count_string = order.lineItems.nodes.size | json | remove: '"' %}

{% comment %} Replace placeholders {% endcomment %}
{% assign email_subject = options.email_subject__required | replace: "ORDER_NUMBER", order.name | replace: "ORDER_TOTAL", order_total_string %}

{% assign email_body = options.email_body__multiline_required | replace: "CUSTOMER_NAME", customer.firstName | default: "there" | replace: "ORDER_NUMBER", order.name | replace: "ORDER_TOTAL", order_total_string | replace: "ITEM_COUNT", item_count_string %}

{% action "email" %}
  {
    "to": {{ customer.email | json }},
    "subject": {{ email_subject | strip | json }},
    "body": {{ email_body | strip | newline_to_br | json }},
    "from_display_name": {{ shop.name | json }},
    "reply_to": {{ shop.customer_email | json }}
  }
{% endaction %}
```

**Default template examples**:

```liquid
"email_subject__required": "Order ORDER_NUMBER confirmed - Total: $ORDER_TOTAL"
"email_body__multiline_required": "Hi CUSTOMER_NAME,\n\nYour order ORDER_NUMBER has been confirmed!\n\nItems: ITEM_COUNT\nTotal: $ORDER_TOTAL\n\nThanks,\n{{ shop.name }}"
```

**Best practices**:
- Use UPPERCASE_WITH_UNDERSCORES for placeholders
- Convert numbers with `| json | remove: '"'`
- Allow Liquid variables like `{{ shop.name }}` in templates
- Always apply `strip` to subjects and `newline_to_br` to bodies
- Document available placeholders in task docs

## Pattern: Throttled Email Alerts

Prevent email flooding with smart throttling:

```liquid
{% comment %} Create throttle key scoped to task.id {% endcomment %}
{% assign throttle_key = "email_sent/" | append: task.id | append: "/" | append: event.topic %}
{% assign last_sent = cache[throttle_key] %}
{% assign now = "now" | date: "%s" %}

{% comment %} Only send if enough time has passed {% endcomment %}
{% if last_sent == nil or now > last_sent | plus: 3600 %}
  {% action "email" %}
    {
      "to": {{ options.alert_email__email_required | json }},
      "subject": "Alert: {{ event.topic }}",
      "body": "This alert is throttled to once per hour maximum."
    }
  {% endaction %}

  {% comment %} Update throttle cache {% endcomment %}
  {% action "cache", "set", throttle_key, now %}
{% else %}
  {% log "Email throttled, last sent", seconds_ago: now | minus: last_sent %}
{% endif %}
```

## Pattern: Email Scheduling with Event Delays

Schedule emails for specific times:

```liquid
{% comment %} Schedule email for 7 days from now {% endcomment %}
{% assign seven_days_later = "now" | date: "%s", advance: "7 days" %}

{% action "event" %}
  {
    "topic": "user/followup/email",
    "data": {
      "order_id": {{ order.id | json }},
      "customer_email": {{ order.email | json }},
      "order_name": {{ order.name | json }}
    },
    "run_at": {{ seven_days_later | json }},
    "task_id": {{ task.id | json }}
  }
{% endaction %}
```

**Handle scheduled email event**:

```liquid
{% if event.topic == "user/followup/email" %}
  {% assign customer_email = event.data.customer_email %}
  {% assign order_name = event.data.order_name %}

  {% action "email" %}
    {
      "to": {{ customer_email | json }},
      "subject": "How was your order {{ order_name }}?",
      "body": "We hope you're enjoying your purchase! Please let us know how we did.",
      "from_display_name": {{ shop.name | json }},
      "reply_to": {{ shop.customer_email | json }}
    }
  {% endaction %}
{% endif %}
```

## Pattern: Email with Dynamic Content

Personalize email content based on data:

```liquid
{% comment %} Build personalized content {% endcomment %}
{% assign customer_name = customer.firstName | default: customer.lastName | default: "valued customer" %}

{% if customer.tags contains "vip" %}
  {% assign greeting = "Dear " | append: customer_name %}
  {% assign closing = "Your dedicated VIP team" %}
{% else %}
  {% assign greeting = "Hi " | append: customer_name %}
  {% assign closing = "Thanks,<br>{{ shop.name }}" %}
{% endif %}

{% capture email_body %}
  {{ greeting }},<br><br>

  Thank you for your order {{ order.name }}!<br><br>

  {% if order.totalPriceSet.shopMoney.amount >= 100 %}
    As a thank you for your large order, we've included a special gift!<br><br>
  {% endif %}

  Order details:<br>
  {% for item in order.lineItems.nodes limit: 5 %}
    - {{ item.title }} ({{ item.quantity }})<br>
  {% endfor %}
  <br>

  {{ closing }}
{% endcapture %}

{% action "email" %}
  {
    "to": {{ order.email | json }},
    "subject": "Thank you for your order {{ order.name }}!",
    "body": {{ email_body | json }},
    "from_display_name": {{ shop.name | json }},
    "reply_to": {{ shop.customer_email | json }}
  }
{% endaction %}
```

## Pattern: Email with Conditional Attachments

Attach files only when certain conditions are met:

```liquid
{% assign attachments = hash %}

{% comment %} Always include invoice {% endcomment %}
{% assign invoice_data = hash %}
{% assign invoice_pdf = hash %}
{% assign invoice_pdf["html"] = invoice_html %}
{% assign invoice_data["pdf"] = invoice_pdf %}
{% assign attachments["invoice.pdf"] = invoice_data %}

{% comment %} Include shipping label if order is fulfilled {% endcomment %}
{% if order.displayFulfillmentStatus == "FULFILLED" %}
  {% assign label_data = hash %}
  {% assign label_pdf = hash %}
  {% assign label_pdf["html"] = shipping_label_html %}
  {% assign label_data["pdf"] = label_pdf %}
  {% assign attachments["shipping-label.pdf"] = label_data %}
{% endif %}

{% action "email" %}
  {
    "to": {{ customer.email | json }},
    "subject": "Order {{ order.name }} documents",
    "body": "Please find your order documents attached.",
    "attachments": {{ attachments | json }}
  }
{% endaction %}
```

## Common Email Best Practices

1. **Always set reply_to**: Use `shop.customer_email` for better deliverability
2. **Use from_display_name**: Makes emails more recognizable
3. **Apply strip to subjects**: Removes leading/trailing whitespace
4. **Apply newline_to_br to bodies**: Converts line breaks to HTML
5. **Validate recipients**: Check email is not blank before sending
6. **Log email sends**: Track what was sent and to whom
7. **Test mode**: Add option to log instead of sending during testing
8. **Personalize**: Use customer names, order details
9. **Keep it concise**: Short subjects, scannable bodies
10. **Mobile-friendly**: Simple HTML, avoid complex layouts

## Troubleshooting

**Problem**: Emails not sending
- Check recipient email is valid and not nil
- Verify shop.customer_email is set (required for some Shopify plans)
- Check action run for errors

**Problem**: Placeholders not replacing
- Ensure placeholder names match exactly (case-sensitive)
- Convert numbers to strings: `value | json | remove: '"'`
- Check that value exists before replacement

**Problem**: Line breaks not showing
- Use `newline_to_br` filter on body
- Or use `<br>` tags directly in template

**Problem**: Emails going to spam
- Set `reply_to` to valid shop email
- Use `from_display_name`
- Avoid spam trigger words
- Keep reasonable sending volume