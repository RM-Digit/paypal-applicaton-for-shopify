ShopifyApp.configure do |config|
  config.application_name = "PayPal Tracking Info Populator"
  config.api_key = ENV['shopify_api_key']
  config.secret = ENV['shopify_api_secret']
  config.scope = "write_orders"
  config.api_version = "2020-01"
  config.embedded_app = true
  config.after_authenticate_job = false
  config.session_repository = "Shop"
  config.webhooks = [
    {topic: 'orders/updated', address: "https://#{ENV['domain']}/webhooks/order_update", format: 'json'},
    {topic: 'app/uninstalled', address: "https://#{ENV['domain']}/uninstall/app_uninstalled", format: 'json'}
    # {topic: 'orders/create', address: "https://#{ENV['domain']}/webhooks/order_create", format: 'json'},
  ]
end