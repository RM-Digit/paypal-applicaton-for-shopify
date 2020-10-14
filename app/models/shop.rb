class Shop < ActiveRecord::Base
  include ShopifyApp::SessionStorage
  def api_version
    ShopifyApp.configuration.api_version
  end

    def order_call(order_status,is_digital,shipping_company,tracking_no,shop_domain)
    	@result = HTTParty.post("https://#{ENV['domain']}/test/update_order_status", 
    	# @result = HTTParty.post("http://192.168.0.102:3000/test/update_order_status", 
        :body => { :order_status => order_status, 
                   :is_digital => is_digital, 
                   :shipping_company => shipping_company, 
                   :tracking_no => tracking_no, 
                   :shop_domain => shop_domain
                 }.to_json,
        :headers => { 'Content-Type' => 'application/json' } )
    	puts "<======result===========#{@result.response.code}======>"
    	return @result
    end
end
