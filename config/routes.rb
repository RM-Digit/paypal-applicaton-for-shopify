Rails.application.routes.draw do
    # root :to => 'home#index'
    root :to => 'order_tool#dashboard'
    get 'order_tool/instructions'
    get 'order_tool/update_instructions', as: :update_instructions

    post 'test/update_order_status'
    mount ShopifyApp::Engine, at: '/'
    # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

    get '/billing/callback', to: 'order_tool#callback', as: :billing_callback
    get '/billing/denied', to: 'order_tool#denied', as: :billing_denied

    # GDPR Webhooks
    post '/gdpr/customers/redact', to: 'gdpr#customers_redact'
    post '/gdpr/shop/redact', to: 'gdpr#shop_redact'
    post '/gdpr/customers/data_request', to: 'gdpr#customers_request'
    post '/gdpr/usage_based_billing', to: 'gdpr#usage_based_billing'

    # Uninstall
    post '/uninstall/app_uninstalled', to: 'uninstall#app_uninstalled'

    # General Endpoints
    get 'billing_info', to: 'general#billing_info'
    get 'contact_us', to: 'general#contact_us'
    get '/billing/influencer_callback', to: 'general#influencer_callback', as: :influencer_billing_callback

end