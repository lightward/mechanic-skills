# frozen_string_literal: true

require 'json'

api_path = ARGV.fetch(0) { abort 'Usage: bundle exec ruby check_examples.rb /path/to/mechanic-api' }
require File.join(File.expand_path(api_path), 'config/environment')

source = File.read(File.expand_path('../references/verified-task-patterns.md', __dir__))
def snippet(source, heading)
  source.split(heading, 2).last.split('```liquid', 2).last.split('```', 2).first
end

def render_example(source, values = {})
  Liquid::Template.parse(source, error_mode: :strict).render!(Liquid::Context.new(values))
end

def output(source, values = {})
  rendered = render_example(source, values).strip
  rendered.empty? ? nil : JSON.parse(rendered)
end

checks = 0
check = ->(name, &block) do
  raise "FAILED: #{name}" unless block.call
  checks += 1
  puts "PASS: #{name}"
end
options = {'tag_to_add__required' => 'processed', 'notification_email__email_required' => 'operator@example.com'}
two_pass = snippet(source, '### Two-Pass Pattern')
first = output(two_pass, {'event'=>{'topic'=>'shopify/orders/paid'}, 'options'=>options, 'order'=>{'admin_graphql_api_id'=>'gid://shopify/Order/42','name'=>'#42'}})
check.call('first pass queues only Shopify mutation') {first.dig('action', 'type') == 'shopify' && first.dig('action','options','query').include?('gid://shopify/Order/42')}
check.call('first pass preserves callback metadata') {first.dig('action','meta') == {'stage'=>'tag_order','order_name'=>'#42','recipient'=>'operator@example.com'}}
action = {'type'=>'shopify','meta'=>first.dig('action','meta'), 'run'=>{'ok'=>true,'result'=>{'data'=>{'tagsAdd'=>{'userErrors'=>[]}}}}}
callback = {'event'=>{'topic'=>'mechanic/actions/perform'}, 'options'=>options, 'action'=>action}
second = output(two_pass, callback)
check.call('successful callback queues only email') {second.dig('action','type') == 'email' && second.dig('action','options','subject') == 'Tagged order #42'}
check.call('terminal email disables further callbacks') {second.dig('action','options','__perform_event') == false}
failed = Marshal.load(Marshal.dump(callback))
failed['action']['run'] = {'ok'=>false, 'error'=>'Shopify rejected the mutation'}
check.call('failed Shopify action never sends confirmation') {!output(two_pass, failed).key?('action')}
unrelated = Marshal.load(Marshal.dump(callback))
unrelated['action']['meta']['stage'] = 'something_else'
check.call('unrelated stage generates no action') {output(two_pass, unrelated).nil?}
unrelated['action']['meta']['stage'] = 'tag_order'
unrelated['action']['type'] = 'email'
check.call('unrelated action type generates no action') {output(two_pass, unrelated).nil?}
check.call('unrelated topic generates no action') {output(two_pass, {'event'=>{'topic'=>'mechanic/scheduler/daily'}, 'options'=>options}).nil?}
%w[shopify/orders/paid mechanic/actions/perform].each do |topic|
  check.call("preview renders #{topic}") {output(two_pass, {'event'=>{'topic'=>topic, 'preview'=>true}, 'options'=>options}).key?('action')}
end
email = snippet(source, '### Email with Placeholder Template')
email_values = {'options'=>{'email_subject__required'=>'Order ORDER_NUMBER','email_body__multiline_required'=>'Hello CUSTOMER_NAME, order ORDER_NUMBER is ready.'},'order'=>{'name'=>'#42', 'email'=>'customer@example.com','customer'=>{}},'shop'=>{'name'=>'Example','customer_email'=>'shop@example.com'}}
check.call('missing customer name falls back without replacing email body') {output(email, email_values).dig('action','options','body') == 'Hello there, order #42 is ready.'}
email_values['order']['customer']['first_name'] = 'Riley'
check.call('webhook customer first_name appears in email') {output(email, email_values).dig('action','options','body').include?('Hello Riley,')}

dry_run = snippet(source, '### test_mode Pattern')
base = {'options'=>{'test_mode__boolean'=>true},'customer'=>{'id'=>'gid://shopify/Customer/42'},'tag'=>'vip','event'=>{}}
check.call('live dry run emits echo only') {output(dry_run, base).dig('action','type') == 'echo'}
base['event']['preview'] = true
check.call('preview with dry run enabled still renders Shopify action') {output(dry_run, base).dig('action','type') == 'shopify'}
base['event'] = {}
base['options']['test_mode__boolean'] = false
check.call('live run with test mode off emits Shopify action') {output(dry_run, base).dig('action','type') == 'shopify'}

# Offline query fixtures: use real Mechanic tags/filters, replacing only API reads.
module OfflineShopifyRead
  def shopify(query)
    state = @context.registers[:offline_reads]
    state[:queries] << query
    state[:responses].shift || state[:fallback]
  end
end
Liquid::Environment.default.register_filter(OfflineShopifyRead)
pagination = snippet(source, '### Pagination')
page1 = {'data'=>{'orders'=>{'nodes'=>[], 'pageInfo'=>{'hasNextPage'=>true,'endCursor'=>'cursor1'}}}}
page2 = {'data'=>{'orders'=>{'nodes'=>[], 'pageInfo'=>{'hasNextPage'=>false,'endCursor'=>nil}}}}
run_pages = ->(responses, event = {}, fallback = nil) do
  state = {queries: [], responses: responses, fallback: fallback}
  context = Liquid::Context.new({'event'=>event}, {}, {offline_reads: state})
  state[:output] = Liquid::Template.parse(pagination, error_mode: :strict).render!(context)
  state
end
check.call('pagination advances to second page and stops') do
  state = run_pages.call([page1, page2])
  state[:queries].length == 2 && state[:queries].last.include?('after: "cursor1"')
end
check.call('pagination preview substitutes fixture for unavailable API read') {run_pages.call([nil], {'preview'=>true})[:queries].length == 1}
check.call('missing connection is an explicit failure') do
  run_pages.call([{'data'=>{}}])[:output].include?('no connection')
end
check.call('stalled cursor is an explicit failure') do
  run_pages.call([page1, page1])[:output].include?('did not advance')
end
# Change only the bound to exercise exhaustion without 100 redundant reads.
short_pagination = pagination.sub('(1..100)', '(1..1)')
context = Liquid::Context.new({'event'=>{}}, {}, {offline_reads: {queries: [], responses:[page1]}})
check.call('exhausted pagination bound is an explicit failure') do
  Liquid::Template.parse(short_pagination, error_mode: :strict).render!(context).include?('Pagination limit reached')
end
# Exercise the API's event-envelope normalization before Liquid rendering.
event = Event.new(topic: 'mechanic/actions/perform', data: action)
environment = event.send(:build_mechanic_action_liquid_environment, Liquid::Context.new)
check.call('callback preview data directly supplies the action fields') do
  render_example('{{ action.type }}|{{ action.meta.stage }}|{{ action.run.ok }}', environment) == 'shopify|tag_order|true'
end
check.call('nested action wrapper is not a valid callback event payload') do
  begin
    Event.new(topic: 'mechanic/actions/perform', data: {'action'=>action}).send(:build_mechanic_action_liquid_environment, Liquid::Context.new)
    false
  rescue StandardError
    true
  end
end
check.call('capture preserves real line breaks for email bodies') do
  render_example("{% capture body %}Line one\nLine two{% endcapture %}{{ body | newline_to_br }}") == "Line one<br />\nLine two"
end

puts "#{checks} behavior checks passed; no actions performed and no Shopify calls made."
