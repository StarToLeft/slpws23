module ProductManager
    def self.check_product_state(product_id)
        product = Product.find(product_id)

        puts product.expiration_date
        puts Time.now

        # Check if the product has a bid and a winner has been picked
        if product.expiration_date < Time.now and !product.is_sold
            # returns false if the product has no bid
            # returns true if the product has a bid and a winner has been picked
            product.pick_winner
        elsif product.is_sold
            true
        else
            false
        end
    end

    def self.place_bid(user_id, product_id, amount)
        # Check the product state
        return [false, 'Product has already been sold'] if check_product_state(product_id)

        # Verify that the bid is higher than the current bid
        bid = Bid.find_highest_bid(product_id)
        return [false, 'Bid amount too low'] if bid && amount <= bid.amount

        # Place the bid
        bid = Bid.new(user_id, product_id, amount, Time.now, false)
        bid.insert

        return [true, 'You won the auction!'] if check_product_state(product_id)

        [true, 'Bid placed successfully']
    end
end
