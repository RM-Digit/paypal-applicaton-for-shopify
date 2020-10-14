require 'json'
require 'rest-client'
require 'date'

class OrderToolController < ShopifyApp::AuthenticatedController
    # before_action :load_current_recurring_charge

    def dashboard
        @shop_domain = ShopifyAPI::Shop.current.myshopify_domain

        if @shop_domain == "homerri.myshopify.com" or @shop_domain == "cablepal-shop.myshopify.com"
            puts " inside of homerii/cablepal"
            # one-time homerii-call
            @application_credits = ShopifyAPI::ApplicationCredit.all

            @application_credits.each do |credit|
                puts "Credit:"
                puts credit.description
                puts credit.amount.to_s
            end

            puts "credit counts:"
            puts @application_credits.count.to_s

            if @application_credits.count == 0
                puts "no application credits, yet"
                if @shop_domain == "cablepal-shop.myshopify.com"
                    application_credit_params = {"description": "Incorrect Usage Charges-  Cable Pals", "amount": 10.00}
                else
                    application_credit_params = {"description": "Incorrect Usage Charges", "amount": 48.00}
                end
                application_credit = ShopifyAPI::ApplicationCredit.new(application_credit_params)

                if application_credit.save
                    puts "Application credit was issued successfully"
                else
                    puts "Application credit FAILED FAILED"
                end
            else
                puts "A credit already exisits - do nothing"
            end
        end


        # call for order_count

        now = Date.today
        thirty_days_ago = (now - 30)
        thirty_days_ago = thirty_days_ago.strftime("%Y-%m-%d")
        puts "Thirty days ago" + thirty_days_ago.inspect
        order_count = ShopifyAPI::Order.count({:fulfillment_status => 'any', :updated_at_min => thirty_days_ago})

        puts "Order count"

        puts order_count.inspect
        # Include a new arg in the paypal info call, so that the row gets made but a proxy is not consumed
        # set a variable to block the dashboard and alert the user to the issue
        # 
        # IF order_count > 2000 - Update/verify that ddb has an entry for the store so that we don't spam the system
        # Q: what if it WAS above 2000, but isn't anymore?
        response = paypal_info_call({"shop_domain" => @shop_domain, "order_count_monthly" => order_count})
        body = JSON.parse(response.body)


        if body['too_many_orders'] == "True"
            puts "Too many orders"
            @too_many_orders = false
        else
            puts "Not a problem"
            @too_many_orders = false
        end


        @recurring_application_charge = ShopifyAPI::RecurringApplicationCharge.current

        @special_billing_details = get_special_billing_details({
            "shop_domain" => @shop_domain,
            "app_name" => "paypal"})

        # if @special_billing_details || !@recurring_application_charge
        if @special_billing_details
            puts "Special billing is present...."
            if !@recurring_application_charge
                puts "Special billing present and no current app charge plan"

                trial_days = @special_billing_details['trial_days'].to_i
                price = @special_billing_details['price'].to_i
                capped_amount = @special_billing_details['capped_amount'].to_i

                billing_setup(price, trial_days, capped_amount)

            # Plan already exists, compare
            else
                if (@recurring_application_charge.price.to_i == @special_billing_details['price'].to_i and 
                    @recurring_application_charge.trial_days.to_i == @special_billing_details['trial_days'].to_i and 
                    @recurring_application_charge.capped_amount.to_i == @special_billing_details['capped_amount'].to_i)
                    puts "No change in billing"
                else
                    puts "Change in billing with special billing item"
                    trial_days = @special_billing_details['trial_days'].to_i
                    price = @special_billing_details['price'].to_i
                    capped_amount = @special_billing_details['capped_amount'].to_i

                    billing_setup(price, trial_days, capped_amount)
                end
            end

            # billing_setup(price, trial_days, capped_amount)
        end

        if !@recurring_application_charge
            puts "No charge, no special_billing_details"

            trial_days = 14
            if body["new_account"] == "false"
                trial_days = 0
            end

            price = 15.00
            capped_amount = 70

            billing_setup(price, trial_days, capped_amount)
        end

        if body['new_path'] == "True"
            if body['client_id'] == ""
                @paypal_not_enabled = true
            else
                @paypal_not_enabled = false
            end
        else
            @paypal_not_enabled = true
        end

        # TODO: make sure these are strings
        @paypal_orders_fulfilled_current = body["current_month_count"]
        @paypal_orders_fulfilled_last = body["last_month_count"]
        @all_time_paypal_orders_fulfilled = body["all_time_count"]

        return
    end

    def instructions
        puts "In the index1"
        @shop_domain = ShopifyAPI::Shop.current.myshopify_domain

        response = paypal_info_call({"shop_domain" => @shop_domain})
        # TODO: This will have a field to dictate what to show


        body = JSON.parse(response.body)

        if body['too_many_orders'] == "True"
            @too_many_orders = true
        else
            @too_many_orders = false
        end


        if body['new_path'] == "True"
            puts "New path is true"
            @new_path = true

            @client_id = body['client_id']
            @secret = body['secret']
        else
            puts "New path is false"
            @new_path = false

        end
        puts "In the index1"
        @username = body["username"]
        @password = body["password"]

        if @username
            @credentials_present = true
            puts "username present"
        else
            puts "No username present"
        end
        return
    end

    def update_instructions
        if request.params["authenticity_token"].present?
            puts "its a post!"
            @shop_domain = ShopifyAPI::Shop.current.myshopify_domain

            client_id = params[:client_id]
            secret = params[:secret]

            puts client_id
            puts secret

            data = {
                "shop_domain" => @shop_domain,
                "client_id" => client_id,
                "secret" => secret
            }

            update_instructions_call(data)
        end

        redirect_to order_tool_instructions_path
    end

    def update_instructions_call(data)
        uri = URI.parse("https://9rk71yp8tb.execute-api.us-east-2.amazonaws.com/default/Update_ClientId_And_Secret")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 120
        http.open_timeout = 120
        header = {'Content-Type': 'text/json'}
        request = Net::HTTP::Get.new(uri.request_uri, header)
        request.body = data.to_json

        response = http.request(request)
        return response
    end

    def paypal_info_call(data)
        uri = URI.parse("https://hd0wjg6iii.execute-api.us-east-2.amazonaws.com/default/getPaypalDetails")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 120
        http.open_timeout = 120
        header = {'Content-Type': 'text/json'}
        request = Net::HTTP::Get.new(uri.request_uri, header)
        request.body = data.to_json

        response = http.request(request)
        return response
    end

    def get_special_billing_details(data)
        puts "Making that billing CALLLLLLL"
        uri = URI.parse("https://43a1zv2rzd.execute-api.us-east-2.amazonaws.com/default/getSpecialBilling")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 120
        http.open_timeout = 120
        header = {'Content-Type': 'text/json'}
        request = Net::HTTP::Get.new(uri.request_uri, header)
        request.body = data.to_json

        response = http.request(request)
        puts "response code:"
        puts response.code

        body = JSON.parse(response.body)

        if body["special_billing_present"] == "false"
            return false
        else
            return body
        end
    end

    def billing_setup(price, trial_days, capped_amount)
        @recurring_application_charge = ShopifyAPI::RecurringApplicationCharge.new(
            name: "Basic Tracking",
            price: price,
            trial_days: trial_days,
            capped_amount: capped_amount,
            terms: "Usage based pricing tiers.  Never pay for more than you use!"
            )

        if !Rails.env.production?
            @recurring_application_charge.test = true
        else
            puts "in production"
        end

        @recurring_application_charge.return_url = billing_callback_url

        if @recurring_application_charge.save
            puts "successfully saved the charge! with price: " + price.to_s
            fullpage_redirect_to @recurring_application_charge.confirmation_url
            return
        else
            puts "failed to saved"

            redirect_to :index
            return
        end
        puts "239"
    end

    def callback
        puts "got the app charge from charge_IDz"
        @recurring_application_charge = ShopifyAPI::RecurringApplicationCharge.find(params[:charge_id])
        puts "pew"
        @shop_domain = ShopifyAPI::Shop.current.myshopify_domain
        puts "got the app charge from charge_ID"
        if @recurring_application_charge.status == 'accepted'

            #  API #1 TODO: -> billing_accepted_register
            #  Increment proxy count, set to installed == true -> only increment proxy count if number of orders all time is == 0
            #  args:  store_name

            billing_accepted_register({"shop_domain" => @shop_domain})
            # This should assign the proxy and increment it.

            @recurring_application_charge.activate
            puts "We successfully activated a billing"
        else

            puts "Denied billing"
            redirect_to billing_denied_url
            return
        end
        puts "we are about to route to index page"
        redirect_to root_url
        return
    end

    def billing_accepted_register(data)
        # TODO: correct endpoint
        uri = URI.parse("https://g8hb5qjcbk.execute-api.us-east-2.amazonaws.com/default/PAYPAL_billing_accepted_register")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 120
        http.open_timeout = 120
        header = {'Content-Type': 'text/json'}
        request = Net::HTTP::Get.new(uri.request_uri, header)
        request.body = data.to_json

        response = http.request(request)
        puts "response code:"
        puts response.code
    end

    def denied

    end

    # def billing_info
    #     if request.params["authenticity_token"].present?
    #         puts "its a post!"
    #         @shop_domain = ShopifyAPI::Shop.current.myshopify_domain

    #         influencer_code = params[:influencer_code]

    #         influencer_billing_hash = get_discount_code_call({"shop_domain": @shop_domain, "discount_code": influencer_code, "app_name": "paypal"})
    #         puts influencer_billing_hash

    #         if influencer_billing_hash['is_valid'] == "true"
    #             puts "influencer hash is valid"

    #             puts "Capped amount"
    #             puts influencer_billing_hash['capped_amount'].to_i.to_s
    #             callback_url = influencer_billing_callback_url
    #             billing_setup(influencer_billing_hash['name'], influencer_billing_hash['price'].to_f, influencer_billing_hash['trial_days'], influencer_billing_hash['capped_amount'].to_i, influencer_billing_hash['terms'], callback_url)

    #             @valid = "true"
    #             return
    #         else
    #             # invalid influencer code
    #             @valid = "false"
    #         end
    #     else
    #         # Get Billing info
    #         # @recurring_application_charge = ShopifyAPI::RecurringApplicationCharge.current
    #         # @name = @recurring_application_charge.name
    #         # @price = @recurring_application_charge.price
    #         # @trial_days = @recurring_application_charge.trial_days

    #         @name = "yolo"
    #         @price = "19.50"
    #         @trial_days = "3"

    #         @valid = "N/A"
    #         puts "Get Billing_info"
    #     end

    #     return
    # end

    # def get_discount_code_call(data)
    #     # TODO: correct uri
    #     uri = URI.parse("https://a7iqqdjvhe.execute-api.us-east-2.amazonaws.com/default/General_DiscountCodes")
    #     http = Net::HTTP.new(uri.host, uri.port)
    #     http.use_ssl = true
    #     http.read_timeout = 120
    #     http.open_timeout = 120
    #     header = {'Content-Type': 'text/json'}
    #     request = Net::HTTP::Post.new(uri.request_uri, header)
    #     request.body = data.to_json

    #     response = http.request(request)
    #     body = JSON.parse(response.body)

    #     puts body
    #     return body
    # end

    # def billing_setup(name, price, trial_days, capped_amount, terms, callback_url)
    #     puts "Here"

    #     if capped_amount.to_s == "0"
    #         puts "no capped level" 
    #         @recurring_application_charge = ShopifyAPI::RecurringApplicationCharge.new(
    #             name: name,
    #             # TODO temp
    #             price: price,
    #             trial_days: trial_days)
    #     else
    #         puts "capped level present"
    #         @recurring_application_charge = ShopifyAPI::RecurringApplicationCharge.new(
    #             name: name,
    #             price: price,
    #             trial_days: trial_days,
    #             capped_amount: capped_amount,
    #             terms: terms)
    #     end

    #     @recurring_application_charge_current = ShopifyAPI::RecurringApplicationCharge.current
    #     if @recurring_application_charge_current
    #         puts "Canceling current application charge"
    #         @recurring_application_charge_current.cancel
    #     end

    #     if !Rails.env.production?
    #         @recurring_application_charge.test = true
    #     else
    #         puts "in production"
    #     end

    #     @recurring_application_charge.return_url = callback_url
    #     if @recurring_application_charge.save
    #         puts "successfully saved the charge!"
    #         fullpage_redirect_to @recurring_application_charge.confirmation_url
    #         return
    #     else
    #         puts "failed to saved"
    #         redirect_to root_url
    #         return
    #     end
    # end

    # def influencer_callback
    #     @recurring_application_charge = ShopifyAPI::RecurringApplicationCharge.find(params[:charge_id])
    #     puts "got the app charge from charge_ID - inside GENERAL CONTROLLER"
    #     if @recurring_application_charge.status == 'accepted'
    #         @recurring_application_charge.activate
    #         puts "We successfully activated a billing"
    #     else
    #         puts "Denied billing"
    #         redirect_to billing_denied_url
    #         return
    #     end
    #     puts "we are about to route to index page"
    #     redirect_to billing_info_url
    #     return
    # end
end