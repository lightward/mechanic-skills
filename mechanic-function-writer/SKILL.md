---
name: mechanic-function-writer
description: Author, edit and test portable Mechanic Function JSON for discounts, cart and checkout validation, bundles, delivery options and payment methods. Use for a rule a merchant will review in the Mechanic Functions builder. Use mechanic-task-writer for event-driven Liquid tasks.
---

# Write a Mechanic Function

For an existing rule, start with the merchant’s **View definition** JSON. For a new rule, choose a matching example below. Return one complete importable file with `format` set to `mechanic/function` and both version fields set to 1. The [v1 schema](references/schema.json) defines the supported fields. If the requested behavior cannot be represented, explain the specific limitation before offering a narrower rule.

| Merchant wants to | Example with saved carts |
| --- | --- |
| Charge a fixed total for a group | [Three items for $30](references/three-items-for-30.json) |
| Require information at checkout | [Require a gift message](references/gift-message-required.json) |
| Split a kit into the variants to ship | [Two-item bundle](references/two-item-bundle.json) |
| Hide express delivery for mixed preorder carts | [Preorder delivery](references/preorder-delivery.json) |
| Hide a payment method above a threshold | [Cash on delivery](references/cash-on-delivery-limit.json) |

Keep qualifying items and rewarded items distinct. For example, a cart threshold can count three qualifying items while the discount applies only to a fourth, different item. Paths run in order and the first match wins. Put an unconditional fallback last. For a validation, state what would block checkout and write a message the buyer can act on.

Use role names such as “Eligible collection” and “Bundle parent” for shop resources. The merchant selects the actual resources in the builder. Preserve the aliases from an existing export. For delivery and payment options, use the checkout names supplied by the merchant and identify any example names that need replacing.

Include a qualifying cart and a boundary cart with an independently calculated expected outcome. For quantity offers, also check the next quantity above the threshold. Preserve existing carts and their expectations when editing. The test cart stores savings as 100 times the amount in the cart currency. For example, three items totaling $50 in USD at a group price of $30 save 2000 cents. Explain which additional units keep their selling price.

In the $30 example, the first five quantity positions are the $18 regular item, $14 preorder, $12 subscription, $20 accessory, and $32 bundle. Three eligible units at $18, $18 and $14 total $50. A fourth $18 unit brings the total after the discount to $48. The example discounts the cheapest units in each complete group, excludes subscriptions, and preserves any lower selling price. Check these choices against the merchant’s intent.

With a CLI version that includes Functions, run `mechanic functions validate <file>` and `mechanic functions preview <file>`. If only the builder is available, use **Import function** for a new rule or **View definition → Review changes** for an edit. Inspect the saved carts and apply the edits to the draft. Check each cart’s status and expected outcome. “Inputs only” means the cart has no expectation. When an expected outcome is pending or estimated, report what still needs to be checked in Shopify. Add an expected result for any behavior the merchant wants to verify and describe any remaining checkout checks. Report which results you actually checked. The merchant can review shop selections, Shopify permissions and publication in Mechanic.
