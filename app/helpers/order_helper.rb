module OrderHelper
	def order_status_change
		@order_note = @order.note
        if @order_note
            ['fulfilled','partial','restocked','unfulfilled'].each do |order_status|
                @order_note = @order_note.gsub("order status updated to #{order_status}","")
            end
        else
            @order_note = ""
        end
		@order.update_attributes(note: "#{@order_note} order status updated to #{@order_status} in Paypal")
		@order_updated = true
	end
end
