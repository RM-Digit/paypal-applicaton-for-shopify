require 'json'
require 'rest-client'
require 'date'
require 'time'
# import Datetime
require 'base64'
require 'openssl'

class UninstallController < ActionController::Base
    skip_before_action :verify_authenticity_token
    # include ShopifyApp::WebhookVerification

    # def verify_webhook(data, hmac_header)
    #     calculated_hmac = Base64.strict_encode64(OpenSSL::HMAC.digest('sha256', ENV['shopify_api_secret'], data))
    #     ActiveSupport::SecurityUtils.secure_compare(calculated_hmac, hmac_header)
    # end

    # TODO: implement these endpoints so they all call 
    def app_uninstalled
        puts("yolo")
        # data = request.body.read
        # # env["HTTP_X_SHOPIFY_HMAC_SHA256"]
        # puts("Putsing REQUESTXXXXX")
        # verified = verify_webhook(data, ENV["HTTP_X_SHOPIFY_HMAC_SHA256"])
        json_obj = request.params.to_json
        # other_obj = request.to_json

        # puts("inspect")
        # puts(params.inspect)

        puts("about to put the request params:")
        # puts(json_obj)
        # puts(other_obj)

        if hmac_valid?(request.raw_post)
            puts("Valid hmac!!!")
            puts("Valid hmac!!!2")
            shop_domain = params['uninstall']['myshopify_domain']

            uninstall_call({"shop_domain" => shop_domain})

            return "Complete"
        else
            puts("not valid")
            return head :unauthorized
        end
    end

    def uninstall_call(data)
        # Not the final URL
        uri = URI.parse("https://dle8x78pu6.execute-api.us-east-2.amazonaws.com/default/PAYPAL_Uninstall")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 120
        http.open_timeout = 120
        header = {'Content-Type': 'text/json'}
        request = Net::HTTP::Get.new(uri.request_uri, header)
        request.body = data.to_json

        response = http.request(request)
        puts(response)
        return response
    end

    def hmac_valid?(data)
        begin
            puts("in the new hmac valid request")
            secret = ShopifyApp.configuration.secret
            digest = OpenSSL::Digest.new('sha256')
            puts(secret)
            puts(digest)
            puts("here1")
            shopify_hmac = request.headers["HTTP_X_SHOPIFY_HMAC_SHA256"]
            puts(shopify_hmac.strip)
            puts("here23")
            encoded_digest = Base64.strict_encode64(OpenSSL::HMAC.digest(digest, secret, data).strip)
            puts(encoded_digest)
            return encoded_digest == shopify_hmac.strip
            # puts("classes")
            # puts(encoded_digest.class)
            # puts(shopify_hmac.class)

            # result = ActiveSupport::SecurityUtils.variable_size_secure_compare(::Digest::SHA256.hexdigest(shopify_hmac), ::Digest::SHA256.hexdigest(encoded_digest))
            # puts(result ? "true" : "false")
            # puts("fffffff")
        rescue => exception
            puts(exception.backtrace)
            puts("A failure hass occured")
            return false
        end
        # puts("GGGGGGGGG")
        # return result
    end
end