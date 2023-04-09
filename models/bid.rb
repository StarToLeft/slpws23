require 'sqlite3'
require 'securerandom'

# The Bid class represents a bid in the database.
#
# @!attribute id
#   @return [String] the universally unique identifier (UUID) of the bid
# @!attribute user_id
#   @return [Integer] the user ID associated with the bid
# @!attribute product_id
#   @return [Integer] the product ID associated with the bid
# @!attribute amount
#   @return [Float] the bid amount
# @!attribute bid_date
#   @return [Time] the date and time the bid was placed
# @!attribute is_accepted
#   @return [Boolean] whether the bid is accepted or not
class Bid
    attr_accessor :id, :user_id, :product_id, :amount, :bid_date, :is_accepted

    # Initializes a new Bid instance with the given user ID, product ID, amount, bid date, and accepted status.
    #
    # @param user_id [Integer] the user ID
    # @param product_id [Integer] the product ID
    # @param amount [Float] the bid amount
    # @param bid_date [Time] the date and time the bid was placed
    # @param is_accepted [Boolean] whether the bid is accepted or not
    def initialize(user_id, product_id, amount, bid_date, is_accepted)
        @id = SecureRandom.uuid
        @user_id = user_id
        @product_id = product_id
        @amount = amount
        @bid_date = bid_date
        @is_accepted = is_accepted
    end

    # @!visibility private
    def self.db
        unless defined?(@db)
            @db = SQLite3::Database.new('./db/marketplace.sqlite')
            @db.execute('PRAGMA foreign_keys = ON')
        end
        @db
    end

    # Finds a bid by its ID.
    #
    # @param id [String] the UUID of the bid to find
    # @return [Bid, nil] the Bid instance if found, or nil if not found
    def self.find(id)
        row = db.execute('SELECT * FROM bids WHERE id = ?', id).first
        return nil unless row

        value = new(*row[1..-1])
        value.id = row[0]
        value
    end

    # Finds bids by their associated user ID.
    #
    # @param user_id [Integer] the user ID to find bids for
    # @return [Array<Bid>] an array of Bid instances
    def self.find_by_user_id(user_id)
        rows = db.execute('SELECT * FROM bids WHERE user_id = ?', user_id)
        return nil unless rows

        values = []
        rows.each do |row|
            value = new(*row[1..-1])
            value.id = row[0]
            values << value
        end
        values
    end

    # Finds bids by their associated product ID.
    #
    # @param product_id [Integer] the product ID to find bids for
    # @return [Array<Bid>] an array of Bid instances
    def self.find_by_product_id(product_id)
        rows = db.execute('SELECT * FROM bids WHERE product_id = ?', product_id)
        return nil unless rows

        values = []
        rows.each do |row|
            value = new(*row[1..-1])
            value.id = row[0]
            values << value
        end
        values
    end

    # Finds the highest bid for a given product ID.
    #
    # @param product_id [Integer] the product ID to find the highest bid for
    # @return [Bid, nil] the Bid instance with the highest amount, or nil if not found
    def self.find_highest_bid(product_id)
        row = db.execute('SELECT * FROM bids WHERE product_id = ? ORDER BY amount DESC LIMIT 1', product_id).first
        return nil unless row

        value = new(*row[1..-1])
        value.id = row[0]
        value
    end

    # Saves a specified field of the Bid instance to the database.
    #
    # @param field [Symbol] the field to save
    # @return [void]
    def save_field(field)
        return if @id.nil?

        # Check if the field exists as a public
        unless respond_to?(field)
            puts "Error: #{field} is not a valid field for the class."
            return
        end

        # Check if the field is a variable, not a method
        if method(field).arity != 0
            puts "Error: #{field} is a method, not a variable, and cannot be saved to the database."
            return
        end

        # Convert data types if necessary
        new_value = send(field)
        if new_value.is_a?(Date) || new_value.is_a?(Time)
            new_value = new_value.iso8601
        elsif new_value.is_a?(TrueClass) || new_value.is_a?(FalseClass)
            new_value = new_value ? 1 : 0
        end
        old_value = self.class.db.execute("SELECT #{field} FROM bids WHERE id = ?", @id).flatten.first

        # Check if the new field value is nil or empty
        if new_value.nil? || new_value.to_s.empty?
            puts "Error: cannot save empty value for #{field}."
            return
        end

        # Check if the new field value is the same as the old field value
        if new_value == old_value
            puts "Warning: no change to #{field} field detected."
            return
        end

        self.class.db.execute("UPDATE bids SET #{field} = ? WHERE id = ?", new_value, @id)
    end

    # Inserts the bid into the database.
    #
    # @return [void]
    def insert
        bid_date = @bid_date.iso8601

        is_accepted = 0
        is_accepted = 1 if @is_accepted == true

        self.class.db.execute(
            'INSERT INTO bids (id, user_id, product_id, amount, bid_date, is_accepted) VALUES (?, ?, ?, ?, ?, ?)', @id, @user_id, @product_id, @amount, bid_date, is_accepted
        )
    end

    # Deletes the bid from the database.
    #
    # @return [void]
    def destroy
        self.class.db.execute('DELETE FROM bids WHERE id = ?', @id)
    end
end
