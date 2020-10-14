require 'json'

class HomeController < ShopifyApp::AuthenticatedController
    before_action :load_current_recurring_charge

	def index
        puts "In the index0"

        # Determine if recurring charge is set
            # if not call billing setup

        # @recurring_application_charge = ShopifyAPI::RecurringApplicationCharge.current
        # if !@recurring_application_charge
        #     puts "No charge"
        #     billing_setup()
        # end

        puts "In the index1"
        @shop_domain = ShopifyAPI::Shop.current.myshopify_domain

        response = paypal_info_call({"shop_domain" => @shop_domain})

        puts "meow"

        body = JSON.parse(response.body)

        puts "In the index2"
        @username = body["username"]
        @password = body["password"]
        return
	end

    def paypal_info_call(data)
        puts "data: + " + data.to_json
        uri = URI.parse("https://hd0wjg6iii.execute-api.us-east-2.amazonaws.com/default/getPaypalDetails")
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
        puts response.message
        return response
    end

    def billing_setup

        @recurring_application_charge = ShopifyAPI::RecurringApplicationCharge.new(
            name: "Basic 350",
            price: 13,
            trial_days: 7,
            capped_amount: 60,
            terms: "We automatically upgrade your plan based on usage.
            $12.50 Base Plan updates 350 orders.
            $22 Startup Plan updates 1000 orders.
            $50 Enterprise Plan updates 3000 orders.
            $10 extra for each 1000 order after that."
            )

        @recurring_application_charge.return_url = billing_callback_url

        if !Rails.env.production?
            @recurring_application_charge.test = true
        else
            puts "in production"
        end

        if @recurring_application_charge.save
            puts "successfully saved the charge!1234"
            fullpage_redirect_to @recurring_application_charge.confirmation_url
            return
        else
            puts "failed to saved"

            redirect_to :index
            return
        end
    end

    def callback
        @recurring_application_charge = ShopifyAPI::RecurringApplicationCharge.find(params[:charge_id])
        puts "got the app charge from charge_ID"
        if @recurring_application_charge.status == 'accepted'
            @recurring_application_charge.activate
            puts "We successfully activated a billing"
        end
        puts "we are about to route to index page"
        redirect_to "/"
    end

    def load_current_recurring_charge
        @recurring_application_charge = ShopifyAPI::RecurringApplicationCharge.current
    end
end
