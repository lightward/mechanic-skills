# Mechanic Patterns: Customer Management

## Pattern: Progressive Customer Tagging

Tag customers based on their lifetime behavior:

```liquid
{% comment %} Get customer's complete order history {% endcomment %}
{% capture query %}
  query {
    customer(id: {{ customer.id | json }}) {
      id
      tags
      ordersCount
      orders(first: 250) {
        nodes {
          totalPriceSet {
            shopMoney {
              amount
            }
          }
        }
      }
    }
  }
{% endcapture %}
{% assign result = query | shopify %}
{% assign customer_data = result.data.customer %}

{% comment %} Calculate lifetime value {% endcomment %}
{% assign lifetime_value = 0 %}
{% for order in customer_data.orders.nodes %}
  {% assign lifetime_value = lifetime_value | plus: order.totalPriceSet.shopMoney.amount %}
{% endfor %}

{% comment %} Progressive tagging based on value {% endcomment %}
{% assign tags_to_add = array %}
{% assign tags_to_remove = array %}

{% if lifetime_value >= 10000 %}
  {% assign tags_to_add[0] = "vip-platinum" %}
  {% assign tags_to_remove[0] = "vip-gold" %}
  {% assign tags_to_remove[1] = "vip-silver" %}
{% elsif lifetime_value >= 5000 %}
  {% assign tags_to_add[0] = "vip-gold" %}
  {% assign tags_to_remove[0] = "vip-silver" %}
  {% unless customer_data.tags contains "vip-platinum" %}
    {% assign tags_to_remove[1] = "vip-platinum" %}
  {% endunless %}
{% elsif lifetime_value >= 1000 %}
  {% assign tags_to_add[0] = "vip-silver" %}
{% endif %}

{% comment %} Apply tag changes {% endcomment %}
{% if tags_to_add != empty or tags_to_remove != empty %}
  {% action "shopify" %}
    mutation {
      {% if tags_to_add != empty %}
        tagsAdd(id: {{ customer.id | json }}, tags: {{ tags_to_add | json }}) {
          userErrors { field message }
        }
      {% endif %}
      {% if tags_to_remove != empty %}
        tagsRemove(id: {{ customer.id | json }}, tags: {{ tags_to_remove | json }}) {
          userErrors { field message }
        }
      {% endif %}
    }
  {% endaction %}
{% endif %}
```

## Pattern: Customer Segmentation with Smart Lists

Automatically segment customers for targeted marketing:

```liquid
{% comment %} Define segment criteria {% endcomment %}
{% assign segment_definitions = hash %}
{% assign segment_definitions["frequent-buyer"] = "ordersCount >= 5" %}
{% assign segment_definitions["high-value"] = "amountSpent.amount >= 1000" %}
{% assign segment_definitions["at-risk"] = "lastOrderDate < 90.days.ago" %}
{% assign segment_definitions["new-customer"] = "ordersCount == 1" %}

{% for segment in segment_definitions %}
  {% capture query %}
    query {
      customers(first: 250, query: {{ segment[1] | json }}) {
        nodes {
          id
          email
          tags
        }
      }
    }
  {% endcapture %}
  {% assign result = query | shopify %}

  {% for customer in result.data.customers.nodes %}
    {% unless customer.tags contains segment[0] %}
      {% action "shopify" %}
        mutation {
          tagsAdd(
            id: {{ customer.id | json }}
            tags: [{{ segment[0] | json }}]
          ) {
            userErrors { field message }
          }
        }
      {% endaction %}
    {% endunless %}
  {% endfor %}
{% endfor %}
```

## Pattern: Win-Back Campaign Triggers

Identify and tag churning customers:

```liquid
{% comment %} Preview mode: skip sending emails and mutations {% endcomment %}
{% assign is_preview = options.preview_mode__boolean | default: false %}

{% comment %} Find customers who haven't ordered recently {% endcomment %}
{% assign days_since_last_order = options.days_since_last_order__number_required | default: 60 %}
{% assign cutoff_date = "now" | date: "%s" | minus: days_since_last_order | times: 86400 | date: "%Y-%m-%d" %}

{% capture query %}
  query {
    customers(
      first: 250
      query: "orders_count:>0 AND -tag:win-back-sent AND last_order_date:<{{ cutoff_date }}"
    ) {
      nodes {
        id
        email
        firstName
        ordersCount
        lastOrder {
          name
          createdAt
        }
      }
    }
  }
{% endcapture %}
{% assign result = query | shopify %}

{% for customer in result.data.customers.nodes %}
  {% comment %} Calculate days since last order {% endcomment %}
  {% assign last_order_date = customer.lastOrder.createdAt | date: "%s" %}
  {% assign now = "now" | date: "%s" %}
  {% assign days_inactive = now | minus: last_order_date | divided_by: 86400 %}

  {% unless is_preview %}
    {% comment %} Tag and trigger win-back email {% endcomment %}
    {% action "shopify" %}
      mutation {
        tagsAdd(
          id: {{ customer.id | json }}
          tags: ["win-back-sent", "churning-customer"]
        ) {
          userErrors { field message }
        }
      }
    {% endaction %}

    {% comment %} Send win-back email with personalized discount {% endcomment %}
    {% assign discount_percentage = 10 %}
    {% if customer.ordersCount > 5 %}
      {% assign discount_percentage = 20 %}
    {% endif %}

    {% action "email" %}
      {
        "to": {{ customer.email | json }},
        "subject": "We miss you, {{ customer.firstName | default: 'friend' }}! Here's {{ discount_percentage }}% off",
        "body": "It's been {{ days_inactive }} days since your last order. Come back with this exclusive discount!",
        "from_display_name": {{ shop.name | json }}
      }
    {% endaction %}
  {% else %}
    {% log
      message: "Preview: Win-back email would be sent",
      customer_id: customer.id,
      email: customer.email,
      days_inactive: days_inactive
    %}
  {% endunless %}
{% endfor %}
```

## Pattern: Customer Account Validation

Validate and clean customer data:

```liquid
{% comment %} Check for duplicate or invalid customer accounts {% endcomment %}
{% capture query %}
  query {
    customers(first: 250, query: "updated_at:>{{ "now" | date: "%s" | minus: 3600 | date: "%Y-%m-%d" }}") {
      nodes {
        id
        email
        phone
        tags
        addresses {
          address1
          city
          provinceCode
          zip
          countryCode
        }
      }
    }
  }
{% endcapture %}
{% assign result = query | shopify %}

{% for customer in result.data.customers.nodes %}
  {% assign issues = array %}

  {% comment %} Check for invalid email {% endcomment %}
  {% unless customer.email contains "@" and customer.email contains "." %}
    {% assign issues[issues.size] = "invalid-email" %}
  {% endunless %}

  {% comment %} Check for missing address {% endcomment %}
  {% if customer.addresses == empty %}
    {% assign issues[issues.size] = "no-address" %}
  {% endif %}

  {% comment %} Check for test/spam indicators {% endcomment %}
  {% assign spam_indicators = "test,temp,fake,abc123,asdf" | split: "," %}
  {% for indicator in spam_indicators %}
    {% if customer.email contains indicator %}
      {% assign issues[issues.size] = "possible-spam" %}
      {% break %}
    {% endif %}
  {% endfor %}

  {% comment %} Tag customers with issues {% endcomment %}
  {% if issues != empty %}
    {% action "shopify" %}
      mutation {
        tagsAdd(
          id: {{ customer.id | json }}
          tags: {{ issues | json }}
        ) {
          userErrors { field message }
        }
      }
    {% endaction %}

    {% log
      message: "Customer data issues found",
      customer_id: customer.id,
      email: customer.email,
      issues: issues
    %}
  {% endif %}
{% endfor %}
```

## Pattern: Birthday Campaign Automation

Track and celebrate customer birthdays:

```liquid
{% comment %} Preview mode: skip mutations and emails {% endcomment %}
{% assign is_preview = options.preview_mode__boolean | default: false %}

{% comment %} Check for customers with birthdays today {% endcomment %}
{% assign today = "now" | date: "%m-%d" %}

{% capture query %}
  query {
    customers(first: 250, query: "tag:birthday-{{ today }}") {
      nodes {
        id
        email
        firstName
        metafield(namespace: "custom", key: "birthday") {
          value
        }
      }
    }
  }
{% endcapture %}
{% assign result = query | shopify %}

{% for customer in result.data.customers.nodes %}
  {% comment %} Create birthday discount code {% endcomment %}
  {% assign discount_code = "BDAY-" | append: customer.id | split: "/" | last | upcase %}

  {% unless is_preview %}
    {% action "shopify" %}
      mutation {
        priceRuleCreate(
          priceRule: {
            title: "Birthday discount for {{ customer.firstName }}"
            customerSelection: {
              forAllCustomers: false
              customerIdsToAdd: [{{ customer.id | json }}]
            }
            validityPeriod: {
              start: {{ "now" | date: "%FT%T%:z" | json }}
              end: {{ "now" | date: "%s" | plus: 2592000 | date: "%FT%T%:z" | json }}
            }
            itemEntitlements: {
              targetAllLineItems: true
            }
            valueV2: {
              percentageValue: 0.15
            }
            usageLimit: 1
            allocationMethod: ACROSS
            targetType: LINE_ITEM
            targetSelection: ALL
          }
          priceRuleDiscountCode: {
            code: {{ discount_code | json }}
          }
        ) {
          priceRule { id }
          userErrors { field message }
        }
      }
    {% endaction %}

    {% action "email" %}
      {
        "to": {{ customer.email | json }},
        "subject": "🎉 Happy Birthday, {{ customer.firstName }}! Here's 15% off",
        "body": "Celebrate your special day with 15% off your next order. Use code: {{ discount_code }}",
        "from_display_name": {{ shop.name | json }}
      }
    {% endaction %}
  {% else %}
    {% log
      message: "Preview: Birthday discount and email would be sent",
      customer_id: customer.id,
      email: customer.email,
      discount_code: discount_code
    %}
  {% endunless %}
{% endfor %}
```