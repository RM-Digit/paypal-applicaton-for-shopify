require 'net/http'
require 'uri'
require 'json'
require 'date'
# require 'kernal'

class OrderUpdateJob < ActiveJob::Base
    # ActiveJob::Base.logger = Logger.new(nil)
    include OrderHelper
    def perform(shop_domain:, webhook:)
        shop = Shop.find_by(shopify_domain: shop_domain)
        puts "CANONICAL Shop Domain:::: " + shop_domain
        @shop_domain = shop_domain

        puts "Order Update Webhook called..........."

        shop.with_shopify_session do
            # do nothing if already processed
            @order_status = webhook['fulfillment_status']
            @order_status = 'unfulfilled' unless @order_status.present?
            if !webhook['note'].to_s.include? "order status updated to #{@order_status}"
                webhook['line_items'].each do |line_item|
                    @is_digital = !line_item["requires_shipping"]
                end
                @shipping_company = webhook['shipping_lines'][0]['title'] rescue ''
                @tracking_no = webhook['fulfillments'][0]['tracking_number'] rescue nil
                @tracking_company = webhook['fulfillments'][0]['tracking_company'] rescue nil
                @order_id = webhook['id']
                # @customer_name = webhook['billing_address']['name']
                @customer_name = webhook['shipping_address']['name']
                @gross_price = webhook['total_price']
                @created_at = webhook['created_at']

                # process only if gateway is paypal and tracking info presents.
                if webhook['gateway'].downcase == "paypal" && @tracking_no.present? && @tracking_company.present?

                    # Add check for approved billing
                    @recurring_application_charge = ShopifyAPI::RecurringApplicationCharge.current
                    if !@recurring_application_charge
                        puts "no recurring app charge"
                        return
                    end
                    puts "recurring app charge exists"



                    # Where billing stuff was



                    @usage_charges = @recurring_application_charge.usage_charges
                    @usage_charges.each do |charge|
                        puts "Charge:"
                        puts charge.description
                        puts charge.price.to_s
                    end

                    puts "Gateway===#{webhook['gateway'].downcase}"
                    puts "Tracking No:===#{@tracking_no}"
                    puts "Tracking Company:===#{@tracking_company}"
                    
                    #update order note
                    @order = ShopifyAPI::Order.find(@order_id)

                    data = {
                        "shop_domain" => @shop_domain,
                        "tracking_info_required" => 'true',
                        "name" => @customer_name,
                        "gross_price" => @gross_price,
                        "order_status" => 'shipped',
                        "tracking_number" => @tracking_no,
                        "shipped_by" => @tracking_company,
                        "created_at" => @created_at,
                        "failure_count" => "0"
                    }

                    puts "Outputting data: "
                    puts data

                    @order_updated = false
                    for i in 0..2
                        puts "calling script"
                        @result = script_call(data)
                        if @result.code == '200'
                            puts "success!"
                            order_status_change
                            break
                        end
                        puts "failure"
                    end
                    if @order_updated == false
                        puts  "order not updated successfully"
                        @order.update_attributes(note: "Error message here") if @order.note != "Error message here" && !@order_updated
                    end



                    number_of_orders = getMonthlyBillingInfo({"shop_domain": @shop_domain})
                    puts "I got the number of orders: " + number_of_orders.to_s
                    number_of_orders = number_of_orders.to_i


                    billing_threshold = false
                    usage_charge_hash = Hash.new

                    # TODO: re-add this to the tool, in MAY
                    puts "pre measure?"
                    # if number_of_orders >= 350 and number_of_orders <= 360
                    #     puts "startup"
                    #     billing_threshold = true
                    #     usage_charge_hash['price'] = 10.00
                    #     usage_charge_hash['description'] = "Startup Plan"
                    # elsif number_of_orders >= 700 and number_of_orders <= 720
                    #     puts "growth"
                    #     billing_threshold = true
                    #     usage_charge_hash['price'] = 12.00
                    #     usage_charge_hash['description'] = "Growth Plan"
                    # elsif number_of_orders >= 1200 and number_of_orders <= 1225
                    #     puts "enterprise"
                    #     billing_threshold = true
                    #     usage_charge_hash['price'] = 14.00
                    #     usage_charge_hash['description'] = "Enterprise Plan"
                    # end

                    if billing_threshold
                        puts "here123"
                        puts rand.to_s
                        puts "meow"
                        random_length = rand(5)
                        print("sleep length" + random_length.to_s)
                        sleep(random_length + (number_of_orders/100).to_i)

                        print("Month and price:")
                        print(Time.now.month.to_s)
                        print(usage_charge_hash['price'].to_s)
                        charge_present = get_registered_usage_charges(@shop_domain + "_MonthNum:" + Time.now.month.to_s + "_" + usage_charge_hash['price'].to_s)
                        # Bill if the charge isn't yet present
                        if charge_present == "false"
                            create_charge = true
                            print("The charge does not yet exist")
                        end

                        # Actually create charge
                        if create_charge
                            puts "Creating usage charge"

                            # registerUsageCharge(@shop_domain, usage_charge_hash['price'], number_of_orders)

                            # TODO: uncomment when we are ready to roll
                            usage_charge = ShopifyAPI::UsageCharge.new(usage_charge_hash)
                            usage_charge.prefix_options[:recurring_application_charge_id] = ShopifyAPI::RecurringApplicationCharge.current.id

                            if usage_charge.save
                                puts "Usage charge was created successfully"

                                registerUsageCharge(@shop_domain, usage_charge_hash['price'], number_of_orders)

                            else
                                puts "Failed to execute billing"
                            end
                        end

                    end

                else
                  puts "nothing happens"
                end
            else
                puts "status already updated"
            end
        end
    end

    def get_registered_usage_charges(request_string)

        uri = URI.parse("https://01s5e1jo49.execute-api.us-east-2.amazonaws.com/default/PAYPAL_Get_Register_Usage_Charge")

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 120
        http.open_timeout = 120
        header = {'Content-Type': 'text/json'}
        request = Net::HTTP::Post.new(uri.request_uri, header)
        data = {"request_string" => request_string}
        request.body = data.to_json

        response = http.request(request)
        puts "response code:"
        puts response.code

        puts "GET REGISTER USAGE CHARGE"
        # TODO: having a problem here
        puts response.body
        body = JSON.parse(response.body)
        present = body['present']

        return present
    end

    def getMonthlyBillingInfo(data)
        puts "YOLOOOO - 0 "
        # TODO: change uri
        uri = URI.parse("https://4horm1xxo7.execute-api.us-east-2.amazonaws.com/default/PAYPAL_Get_Monthly_Billing_Info")

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 120
        http.open_timeout = 120
        header = {'Content-Type': 'text/json'}
        request = Net::HTTP::Post.new(uri.request_uri, header)
        request.body = data.to_json

        response = http.request(request)
        puts "response code:"
        puts response.code

        puts "YOLO1"
        # TODO: having a problem here
        puts response.body
        body = JSON.parse(response.body)
        number_of_orders = body['number_of_orders']
        puts "YOOLO: " + number_of_orders.to_s
        puts "YOLO2"
        return number_of_orders
    end

    def registerUsageCharge(shop_domain, price, order_count)

        data = {
            "shop_domain" => shop_domain,
            "price" => price,
            "order_count" => order_count
        }
        # TODO: change uri
        uri = URI.parse("https://6f4zjshmv6.execute-api.us-east-2.amazonaws.com/default/PAYPAL_Register_Usage_Charge")

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 120
        http.open_timeout = 120
        header = {'Content-Type': 'text/json'}
        request = Net::HTTP::Post.new(uri.request_uri, header)
        request.body = data.to_json

        response = http.request(request)
        puts "response code:"
        puts response.code
        puts response.message
        return response

    end

    def script_call(data)
        uri = URI.parse("https://drcor1b8e7.execute-api.us-east-2.amazonaws.com/default/orderUpdateQueuing")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 120
        http.open_timeout = 120
        header = {'Content-Type': 'text/json'}
        request = Net::HTTP::Post.new(uri.request_uri, header)
        request.body = data.to_json

        response = http.request(request)
        puts "response code:"
        puts response.code
        puts response.message
        return response
    end
end
