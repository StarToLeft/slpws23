module ProductManager
    def self.check_product_state(product)
        # Check if the product has a bid and a winner has been picked
        if product.expiration_date < Time.now and !product.is_sold
            # returns false if the product has no bid
            # returns true if the product has a bid and a winner has been picked
            return product.pick_winner
        elsif product.is_sold
            return true
        else
            return false
        end
    end

    def self.place_bid(user, product, amount)
        # Check the product state
        if check_product_state(product)
            return false
        end

        # Verify that the bid is higher than the current bid
        bid = Bid.find_highest_bid(product.id)
        return false if bid && amount <= bid.amount

        # Place the bid
        bid = Bid.new(user.id, product.id, amount, Time.now, false)
        bid.insert

        return true
    end
end
