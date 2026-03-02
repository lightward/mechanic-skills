# Mechanic Patterns: Order Processing

## Pattern: Simple Order Validation

Basic order checks and tagging:

```liquid
{% if event.preview %}
  {% assign order = hash %}
  {% assign order["admin_graphql_api_id"] = "gid://shopify/Order/1234567890" %}
  {% assign order["name"] = "#1001" %}
  {% assign order["billingAddress"] = hash %}
  {% assign order["billingAddress"]["city"] = "New York" %}
  {% assign order["shippingAddress"] = hash %}
  {% assign order["shippingAddress"]["city"] = "New York" %}
  {% assign order["totalPriceSet"] = hash %}
  {% assign order["totalPriceSet"]["shopMoney"] = hash %}
  {% assign order["totalPriceSet"]["shopMoney"]["amount"] = 600 %}
  {% assign customer = hash %}
  {% assign customer["ordersCount"] = 1 %}
{% endif %}

{% comment %} Simple validation checks {% endcomment %}
{% assign needs_review = false %}
{% assign review_reasons = array %}

{% comment %} Check for high-value first-time orders {% endcomment %}
{% if customer.ordersCount == 1 and order.totalPriceSet.shopMoney.amount > 500 %}
  {% assign needs_review = true %}
  {% assign review_reasons[review_reasons.size] = "first-order-high-value" %}
{% endif %}

{% comment %} Check for address mismatch {% endcomment %}
{% if order.billingAddress.city != order.shippingAddress.city %}
  {% assign needs_review = true %}
  {% assign review_reasons[review_reasons.size] = "different-cities" %}
{% endif %}

{% comment %} Tag order if review needed {% endcomment %}
{% if needs_review %}
  {% action "shopify" %}
    mutation {
      orderUpdate(input: {
        id: {{ order.admin_graphql_api_id | json }}
        tags: ["needs-review"]
        note: "Review reasons: {{ review_reasons | join: ', ' }}"
      }) {
        userErrors { field message }
      }
    }
  {% endaction %}

  {% comment %} Send simple notification {% endcomment %}
  {% action "email" %}
    {
      "to": {{ options.notification_email__email_required | json }},
      "subject": "Order {{ order.name }} needs review",
      "body": "Please review order {{ order.name }}. Reasons: {{ review_reasons | join: ', ' }}",
      "from_display_name": {{ shop.name | json }}
    }
  {% endaction %}
{% endif %}
```

## Pattern: Tag Orders by Fulfillment Location

Simple location-based order tagging:

```liquid
{% if event.preview %}
  {% assign order = hash %}
  {% assign order["admin_graphql_api_id"] = "gid://shopify/Order/1234567890" %}
  {% assign order["fulfillmentOrders"] = hash %}
  {% assign order["fulfillmentOrders"]["nodes"] = array %}
  {% assign first_location = hash %}
  {% assign first_location["assignedLocation"] = hash %}
  {% assign first_location["assignedLocation"]["id"] = "gid://shopify/Location/123" %}
  {% assign first_location["assignedLocation"]["name"] = "Warehouse East" %}
  {% assign order["fulfillmentOrders"]["nodes"][0] = first_location %}
{% endif %}

{% comment %} Get primary fulfillment location {% endcomment %}
{% assign location_id = order.fulfillmentOrders.nodes.first.assignedLocation.id %}
{% assign location_name = order.fulfillmentOrders.nodes.first.assignedLocation.name %}

{% comment %} Tag order with location {% endcomment %}
{% assign location_tag = "location-" | append: location_name | handleize %}

{% action "shopify" %}
  mutation {
    orderUpdate(input: {
      id: {{ order.admin_graphql_api_id | json }}
      tags: [{{ location_tag | json }}]
    }) {
      userErrors { field message }
    }
  }
{% endaction %}

{% comment %} Notify if specific location {% endcomment %}
{% if location_name == "Warehouse East" %}
  {% action "email" %}
    {
      "to": "warehouse-east@example.com",
      "subject": "New order for Warehouse East: {{ order.name }}",
      "body": "Order {{ order.name }} has been assigned to your location."
    }
  {% endaction %}
{% endif %}
```

## Pattern: Bundle Order Detection

Tag orders that contain product bundles:

```liquid
{% if event.preview %}
  {% assign order = hash %}
  {% assign order["admin_graphql_api_id"] = "gid://shopify/Order/1234567890" %}
  {% assign order["lineItems"] = hash %}
  {% assign order["lineItems"]["nodes"] = array %}
  {% assign item1 = hash %}
  {% assign item1["variant"] = hash %}
  {% assign item1["variant"]["sku"] = "SKU-001" %}
  {% assign order["lineItems"]["nodes"][0] = item1 %}
{% endif %}

{% comment %} Define simple bundle: Buy A+B+C together {% endcomment %}
{% assign bundle_skus = options.bundle_skus__required | split: "," | map: "strip" %}
{% assign bundle_tag = options.bundle_tag__required | default: "bundle-order" %}

{% comment %} Check if order contains all bundle items {% endcomment %}
{% assign order_skus = order.lineItems.nodes | map: "variant.sku" %}
{% assign has_bundle = true %}

{% for required_sku in bundle_skus %}
  {% unless order_skus contains required_sku %}
    {% assign has_bundle = false %}
    {% break %}
  {% endunless %}
{% endfor %}

{% comment %} Tag and notify if bundle detected {% endcomment %}
{% if has_bundle %}
  {% action "shopify" %}
    mutation {
      orderUpdate(input: {
        id: {{ order.admin_graphql_api_id | json }}
        tags: [{{ bundle_tag | json }}]
        note: "Bundle detected: {{ bundle_skus | join: ' + ' }}"
      }) {
        userErrors { field message }
      }
    }
  {% endaction %}

  {% action "email" %}
    {
      "to": {{ order.email | json }},
      "subject": "Thanks for purchasing our bundle!",
      "body": "You've purchased our complete bundle package. Enjoy!",
      "from_display_name": {{ shop.name | json }}
    }
  {% endaction %}
{% endif %}
```

## Pattern: Priority Order Handling

Expedite processing for VIP or urgent orders:

```liquid
{% if event.preview %}
  {% assign order = hash %}
  {% assign order["admin_graphql_api_id"] = "gid://shopify/Order/1234567890" %}
  {% assign order["shippingLines"] = array %}
  {% assign order["totalPriceSet"] = hash %}
  {% assign order["totalPriceSet"]["shopMoney"] = hash %}
  {% assign order["totalPriceSet"]["shopMoney"]["amount"] = 1200 %}
  {% assign order["fulfillmentOrders"] = hash %}
  {% assign order["fulfillmentOrders"]["nodes"] = array %}
  {% assign fo = hash %}
  {% assign fo["id"] = "gid://shopify/FulfillmentOrder/123" %}
  {% assign order["fulfillmentOrders"]["nodes"][0] = fo %}
  {% assign customer = hash %}
  {% assign customer["displayName"] = "John Smith" %}
  {% assign customer["tags"] = array %}
{% endif %}

{% comment %} Check priority conditions {% endcomment %}
{% assign is_priority = false %}
{% assign priority_reason = "" %}

{% comment %} VIP customer check {% endcomment %}
{% if customer.tags contains "vip" or customer.tags contains "platinum" %}
  {% assign is_priority = true %}
  {% assign priority_reason = "VIP Customer" %}
{% endif %}

{% comment %} Express shipping check {% endcomment %}
{% for line in order.shippingLines %}
  {% if line.title contains "Express" or line.title contains "Overnight" %}
    {% assign is_priority = true %}
    {% assign priority_reason = priority_reason | append: " Express Shipping" %}
  {% endif %}
{% endfor %}

{% comment %} High value order check {% endcomment %}
{% if order.totalPriceSet.shopMoney.amount > 1000 %}
  {% assign is_priority = true %}
  {% assign priority_reason = priority_reason | append: " High Value" %}
{% endif %}

{% if is_priority %}
  {% comment %} Tag for priority handling {% endcomment %}
  {% action "shopify" %}
    mutation {
      orderUpdate(input: {
        id: {{ order.admin_graphql_api_id | json }}
        tags: ["priority", "expedite"]
        note: "PRIORITY ORDER - {{ priority_reason }}"
      }) {
        userErrors { field message }
      }
    }
  {% endaction %}

  {% comment %} Move to front of fulfillment queue {% endcomment %}
  {% action "shopify" %}
    mutation {
      fulfillmentOrderMove(
        id: {{ order.fulfillmentOrders.nodes.first.id | json }}
        newLocationId: {{ options.priority_location_id | json }}
      ) {
        userErrors { field message }
      }
    }
  {% endaction %}

  {% comment %} Notify warehouse team {% endcomment %}
  {% action "slack" %}
    {
      "channel": "#warehouse-priority",
      "text": "🚨 Priority Order: {{ order.name }}",
      "attachments": [
        {
          "color": "warning",
          "fields": [
            {
              "title": "Reason",
              "value": {{ priority_reason | json }},
              "short": true
            },
            {
              "title": "Customer",
              "value": {{ order.customer.displayName | json }},
              "short": true
            }
          ]
        }
      ]
    }
  {% endaction %}
{% endif %}
```

## Pattern: Multi-Location Order Alert

Notify when orders require fulfillment from multiple locations:

```liquid
{% if event.preview %}
  {% assign order = hash %}
  {% assign order["admin_graphql_api_id"] = "gid://shopify/Order/1234567890" %}
  {% assign order["fulfillmentOrders"] = hash %}
  {% assign order["fulfillmentOrders"]["nodes"] = array %}
  {% assign loc1 = hash %}
  {% assign loc1["assignedLocation"] = hash %}
  {% assign loc1["assignedLocation"]["name"] = "Warehouse East" %}
  {% assign loc2 = hash %}
  {% assign loc2["assignedLocation"] = hash %}
  {% assign loc2["assignedLocation"]["name"] = "Warehouse West" %}
  {% assign order["fulfillmentOrders"]["nodes"][0] = loc1 %}
  {% assign order["fulfillmentOrders"]["nodes"][1] = loc2 %}
  {% assign order["email"] = "customer@example.com" %}
  {% assign order["name"] = "#1001" %}
  {% assign shop = hash %}
  {% assign shop["name"] = "My Store" %}
{% endif %}

{% comment %} Check if order has multiple fulfillment orders {% endcomment %}
{% assign fulfillment_locations = order.fulfillmentOrders.nodes | map: "assignedLocation.name" | uniq %}

{% if fulfillment_locations.size > 1 %}
  {% comment %} Tag order as multi-location {% endcomment %}
  {% action "shopify" %}
    mutation {
      orderUpdate(input: {
        id: {{ order.admin_graphql_api_id | json }}
        tags: ["multi-location"]
        note: "Ships from: {{ fulfillment_locations | join: ', ' }}"
      }) {
        userErrors { field message }
      }
    }
  {% endaction %}

  {% comment %} Notify customer about multiple shipments {% endcomment %}
  {% action "email" %}
    {
      "to": {{ order.email | json }},
      "subject": "Your order {{ order.name }} will arrive in multiple shipments",
      "body": "To get your order to you faster, items will ship from {{ fulfillment_locations.size }} locations.",
      "from_display_name": {{ shop.name | json }}
    }
  {% endaction %}
{% endif %}
```
