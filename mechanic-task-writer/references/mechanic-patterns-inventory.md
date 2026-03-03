# Mechanic Patterns: Inventory Management

## Pattern: Track Inventory Changes

```liquid
{% comment %} Preview mode: skip sending emails {% endcomment %}
{% assign is_preview = options.preview_mode__boolean | default: false %}

{% comment %} Track when inventory changes {% endcomment %}
{% assign cache_key = "last_inventory:" | append: variant.id %}
{% assign last_inventory = cache[cache_key] | default: variant.inventoryQuantity %}

{% if last_inventory != variant.inventoryQuantity %}
  {% assign change = variant.inventoryQuantity | minus: last_inventory %}

  {% log
    message: "Inventory changed",
    variant: variant.sku,
    from: last_inventory,
    to: variant.inventoryQuantity,
    change: change
  %}

  {% comment %} Update cache for next run - this is ASYNC {% endcomment %}
  {% action "cache", "set", cache_key, variant.inventoryQuantity %}

  {% if variant.inventoryQuantity <= 5 and last_inventory > 5 %}
    {% unless is_preview %}
      {% action "email" %}
        {
          "to": {{ options.alert_email | json }},
          "subject": "Low stock: {{ product.title }}",
          "body": "SKU {{ variant.sku }} has {{ variant.inventoryQuantity }} units left"
        }
      {% endaction %}
    {% else %}
      {% log
        message: "Preview: Low stock alert email would be sent",
        product: product.title,
        sku: variant.sku,
        quantity: variant.inventoryQuantity
      %}
    {% endunless %}
  {% endif %}
{% endif %}
```

## Pattern: Sync Inventory Across Locations

```liquid
{% comment %} Preview mode: skip mutations {% endcomment %}
{% assign is_preview = options.preview_mode__boolean | default: false %}

{% comment %} Get inventory at all locations {% endcomment %}
{% capture query %}
  query {
    productVariant(id: {{ variant_id | json }}) {
      inventoryItem {
        inventoryLevels(first: 20) {
          nodes {
            location { id name }
            quantities(names: ["available"]) {
              quantity
            }
          }
        }
      }
    }
  }
{% endcapture %}
{% assign result = query | shopify %}

{% comment %} Find imbalances and rebalance {% endcomment %}
{% assign total = 0 %}
{% assign locations = array %}

{% for level in result.data.productVariant.inventoryItem.inventoryLevels.nodes %}
  {% assign total = total | plus: level.quantities.first.quantity %}
  {% assign locations = locations | push: level %}
{% endfor %}

{% assign target_per_location = total | divided_by: locations.size | round %}

{% for location in locations %}
  {% assign current = location.quantities.first.quantity %}
  {% assign adjustment = target_per_location | minus: current %}

  {% if adjustment != 0 %}
    {% unless is_preview %}
      {% action "shopify" %}
        mutation {
          inventoryAdjustQuantities(
            input: {
              reason: "restock"
              name: "available"
              changes: [{
                inventoryItemId: {{ result.data.productVariant.inventoryItem.id | json }}
                locationId: {{ location.location.id | json }}
                delta: {{ adjustment }}
              }]
            }
          ) {
            userErrors { field message }
          }
        }
      {% endaction %}
    {% else %}
      {% log
        message: "Preview: Inventory adjustment would be applied",
        location: location.location.name,
        current: current,
        adjustment: adjustment,
        target: target_per_location
      %}
    {% endunless %}
  {% endif %}
{% endfor %}
```

## Pattern: Reserve Inventory for VIP Customers

```liquid
{% comment %} Preview mode: skip mutations {% endcomment %}
{% assign is_preview = options.preview_mode__boolean | default: false %}

{% comment %} Loop prevention: only process once per order/variant combination {% endcomment %}
{% assign loop_prevention_key = "vip_reserved/" | append: task.id | append: "/" | append: order.id | append: "/" | append: variant.id %}
{% assign already_processed = cache[loop_prevention_key] %}

{% unless already_processed %}
  {% if customer.tags contains "VIP" %}
    {% comment %} Check if VIP inventory pool exists {% endcomment %}
    {% assign vip_inventory_key = "vip_reserved:" | append: variant.id %}
    {% assign vip_reserved = cache[vip_inventory_key] | default: 0 %}

    {% if vip_reserved >= line_item.quantity %}
      {% comment %} Mark as processed to prevent loops {% endcomment %}
      {% action "cache", "set", loop_prevention_key, "true" %}

      {% comment %} Fulfill from VIP pool {% endcomment %}
      {% assign new_reserved = vip_reserved | minus: line_item.quantity %}
      {% action "cache", "set", vip_inventory_key, new_reserved %}

      {% unless is_preview %}
        {% action "shopify" %}
          mutation {
            orderUpdate(input: {
              id: {{ order.id | json }}
              customAttributes: [{
                key: "vip_fulfilled"
                value: "true"
              }]
            }) {
              userErrors { field message }
            }
          }
        {% endaction %}
      {% else %}
        {% log
          message: "Preview: VIP order fulfillment would be applied",
          order_id: order.id,
          quantity: line_item.quantity
        %}
      {% endunless %}
    {% endif %}
  {% endif %}
{% else %}
  {% log
    message: "Loop prevention: VIP fulfillment already processed for this order",
    order_id: order.id
  %}
{% endunless %}
```