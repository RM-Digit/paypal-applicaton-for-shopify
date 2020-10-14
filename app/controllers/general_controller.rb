require 'json'
require 'rest-client'
require 'date'
require 'time'

class GeneralController < ShopifyApp::AuthenticatedController

    def billing_info
        if request.params["authenticity_token"].present?
            puts "its a post!"
            @shop_domain = ShopifyAPI::Shop.current.myshopify_domain

            influencer_code = params[:influencer_code]

            influencer_billing_hash = get_discount_code_call({"shop_domain": @shop_domain, "discount_code": influencer_code, "app_name": "paypal"})
            puts influencer_billing_hash

            if influencer_billing_hash['is_valid'] == "true"
                puts "influencer hash is valid"

                puts "Capped amount"
                puts influencer_billing_hash['capped_amount'].to_i.to_s
                callback_url = influencer_billing_callback_url
                billing_setup(influencer_billing_hash['name'], influencer_billing_hash['price'].to_f, influencer_billing_hash['trial_days'], influencer_billing_hash['capped_amount'].to_i, influencer_billing_hash['terms'], callback_url)

                @valid = "true"
                return
            else
                # invalid influencer code
                @valid = "false"
                return
            end
        else
            # Get Billing info
            @recurring_application_charge = ShopifyAPI::RecurringApplicationCharge.current
            @name = @recurring_application_charge.name
            @price = @recurring_application_charge.price
            @trial_days = @recurring_application_charge.trial_days

            @valid = "N/A"
            puts "Get Billing_info"
            return
        end

        return
    end

    def contact_us
        if request.params["authenticity_token"].present?
            puts "its a post!"
            @shop_domain = ShopifyAPI::Shop.current.myshopify_domain

            text = "Name: " + params[:txtName] + "\n"
            text = text + "Email: " + params[:txtEmail] + "\n"
            text = text + "Message: " + params[:txtMessage] + "\n"
            text = text + "Store: " + @shop_domain


            # TODO: change this to be for/to the correct email addreses.

            RestClient.post "https://api:key-b61036acda892d9a6a50672913c0dde3"\
            "@api.mailgun.net/v3/mg.tannerblumer.com/messages",
            :from => "PayPal Tracking Info <mailgun@mg.tannerblumer.com>",
            :to => "campus.martius.software@gmail.com, tanner@mg.tannerblumer.com",
            :subject => "A Customer Has Contacted You",
            :text => text
            return
        end
    end

    def get_discount_code_call(data)
        # TODO: correct uri
        uri = URI.parse("https://koc1fbnevk.execute-api.us-east-2.amazonaws.com/default/General_DiscountCodes")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 120
        http.open_timeout = 120
        header = {'Content-Type': 'text/json'}
        request = Net::HTTP::Post.new(uri.request_uri, header)
        request.body = data.to_json

        response = http.request(request)
        body = JSON.parse(response.body)

        puts body
        return body
    end

    def billing_setup(name, price, trial_days, capped_amount, terms, callback_url)
        puts "Here"

        if capped_amount.to_s == "0"
            puts "no capped level" 
            @recurring_application_charge = ShopifyAPI::RecurringApplicationCharge.new(
                name: name,
                # TODO temp
                price: price,
                trial_days: trial_days)
        else
            puts "capped level present"
            @recurring_application_charge = ShopifyAPI::RecurringApplicationCharge.new(
                name: name,
                price: price,
                trial_days: trial_days,
                capped_amount: capped_amount,
                terms: terms)
        end

        @recurring_application_charge_current = ShopifyAPI::RecurringApplicationCharge.current
        if @recurring_application_charge_current
            puts "Canceling current application charge"
            @recurring_application_charge_current.cancel
        end

        if !Rails.env.production?
            @recurring_application_charge.test = true
        else
            puts "in production"
        end

        @recurring_application_charge.return_url = callback_url
        if @recurring_application_charge.save
            puts "successfully saved the charge!"
            fullpage_redirect_to @recurring_application_charge.confirmation_url
            return
        else
            puts "failed to saved"
            redirect_to root_url
            return
        end
    end

    def influencer_callback
        @recurring_application_charge = ShopifyAPI::RecurringApplicationCharge.find(params[:charge_id])
        puts "got the app charge from charge_ID - inside GENERAL CONTROLLER"
        if @recurring_application_charge.status == 'accepted'
            @recurring_application_charge.activate
            puts "We successfully activated a billing"
        else
            puts "Denied billing"
            redirect_to billing_denied_url
            return
        end
        puts "we are about to route to index page"
        redirect_to billing_info_url
        return
    end
end
