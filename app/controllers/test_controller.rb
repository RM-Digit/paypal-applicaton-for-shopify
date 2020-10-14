class TestController < ApplicationController
	protect_from_forgery with: :null_session
	def update_order_status
	  	puts "<===api called======#{params}===========>"
	  	render json: {}, status: 200
	end
end
