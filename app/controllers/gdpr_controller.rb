require 'json'
require 'rest-client'
require 'date'
require 'time'
# import Datetime

class GdprController < ActionController::Base
    skip_before_action :verify_authenticity_token

    # TODO: implement these endpoints so they all call 
    def customers_redact
        json_obj = request.params.to_json

        puts(json_obj)

        put_gdpr_data(json_obj)

        return
    end

    def shop_redact
        json_obj = request.params.to_json

        puts(json_obj)

        put_gdpr_data(json_obj)
        return
    end

    def customers_request
        json_obj = request.params.to_json

        puts(json_obj)

        put_gdpr_data(json_obj)
        return
    end


    def put_gdpr_data(data)
        uri = URI.parse("https://43z36sm8ec.execute-api.us-east-2.amazonaws.com/default/General_GDPR_DUMP")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 120
        http.open_timeout = 120
        header = {'Content-Type': 'text/json'}
        request = Net::HTTP::Post.new(uri.request_uri, header)
        request.body = data

        response = http.request(request)
        return response
    end



    # TODO: Pull from the request  -shop_domain and billing_amount and billing_name


    def usage_based_billing
        puts request
        puts request.params.to_json

        shop_domain = ""
        price = 0
        description = ""
        if request.params["shop_domain"].present?
            puts "params present"

            shop_domain = request.params["shop_domain"]
            description = request.params["description"]
            price = request.params["price"].to_f.round(2)

            puts price.to_s
        else
            puts "missing params"
            return
        end

        # shop_domain = "cablepal-shop.myshopify.com"
        shop = Shop.find_by(shopify_domain: shop_domain)

        usage_charge_hash = Hash.new
        usage_charge_hash['price'] = price
        usage_charge_hash['description'] = description

        shop.with_shopify_session do
            usage_charge = ShopifyAPI::UsageCharge.new(usage_charge_hash)
            usage_charge.prefix_options[:recurring_application_charge_id] = ShopifyAPI::RecurringApplicationCharge.current.id

            if usage_charge.save
                puts "Usage charge was created successfully"
                # registerUsageCharge(@shop_domain, usage_charge_hash['price'], number_of_orders)
            else
                puts "Failed to execute billing"
            end
        end
        return
    end












end