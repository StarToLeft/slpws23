require 'sqlite3'

# The Bid class represents a bid in the database.
#
# @!attribute [rw] id
#   @return [String] the unique identifier for the product
# @!attribute [rw] user_id
#   @return [String] the unique identifier of the user who created the product
# @!attribute [rw] title
#   @return [String] the title of the product
# @!attribute [rw] description
#   @return [String] the description of the product
# @!attribute [rw] creation_date
#   @return [Time] the creation date of the product
# @!attribute [rw] expiration_date
#   @return [Time] the expiration date of the product
# @!attribute [rw] is_sold
#   @return [Boolean, nil] whether the product is sold (true), not sold (false), or not set (nil)
# @!attribute [rw] sold_date
#   @return [Time, nil] the date the product was sold or nil if not sold
# @!attribute [rw] winner_user_id
#   @return [String, nil] the unique identifier of the user who won the product or nil if not won
class Product
    attr_accessor :id, :user_id, :title, :description, :creation_date, :expiration_date, :is_sold, :sold_date,
                  :winner_user_id

    # Initializes a new Product object.
    #
    # @param user_id [String] the unique identifier of the user who created the product
    # @param title [String] the title of the product
    # @param description [String] the description of the product
    # @param creation_date [Time] the creation date of the product
    # @param expiration_date [Time] the expiration date of the product
    # @param is_sold [Boolean, nil] whether the product is sold (defaults to nil)
    # @param sold_date [Time, nil] the date the product was sold (defaults to nil)
    # @param winner_user_id [String, nil] the unique identifier of the user who won the product (defaults to nil)
    def initialize(user_id, title, description, creation_date, expiration_date, is_sold = nil, sold_date = nil,
                   winner_user_id = nil)
        @id = SecureRandom.uuid
        @user_id = user_id
        @title = title
        @description = description
        @creation_date = creation_date
        @expiration_date = expiration_date
        @is_sold = is_sold
        @sold_date = sold_date
        @winner_user_id = winner_user_id
    end

    # @!visibility private
    def self.db
        unless defined?(@db)
            @db = SQLite3::Database.new('./db/marketplace.sqlite')
            @db.execute('PRAGMA foreign_keys = ON')
        end
        @db
    end

    # Retrieves all products from the database.
    #
    # @return [Array<Product>] an array of Product objects
    def self.all
        db.execute('SELECT * FROM products').map do |row|
            # Translate the data types of certain fields
            row[4] = Time.iso8601(row[4]) if row[4]
            row[5] = Time.iso8601(row[5]) if row[5]
            row[6] = row[6] == 1 if row[6]
            row[7] = Time.iso8601(row[7]) if row[7]
            value = new(*row[1..-1])
            value.id = row[0]
            value
        end
    end

    # Finds products by the winner user ID.
    #
    # @param winner_user_id [String] the unique identifier of the winning user
    # @return [Array<Product>] an array of Product objects
    def self.find_by_winner_user_id(winner_user_id)
        db.execute('SELECT * FROM products WHERE winner_user_id = ?', winner_user_id).map do |row|
            # Translate the data types of certain fields
            row[4] = Time.iso8601(row[4]) if row[4]
            row[5] = Time.iso8601(row[5]) if row[5]
            row[6] = row[6] == 1 if row[6]
            row[7] = Time.iso8601(row[7]) if row[7]
            value = new(*row[1..-1])
            value.id = row[0]
            value
        end
    end

    # Finds products by the user ID.
    #
    # @param user_id [String] the unique identifier of the user who created the product
    # @return [Array<Product>] an array of Product objects
    def self.find_by_user_id(user_id)
        db.execute('SELECT * FROM products WHERE user_id = ?', user_id).map do |row|
            # Translate the data types of certain fields
            row[4] = Time.iso8601(row[4]) if row[4]
            row[5] = Time.iso8601(row[5]) if row[5]
            row[6] = row[6] == 1 if row[6]
            row[7] = Time.iso8601(row[7]) if row[7]
            value = new(*row[1..-1])
            value.id = row[0]
            value
        end
    end

    # Finds a product by its ID.
    #
    # @param id [String] the unique identifier of the product
    # @return [Product, nil] the Product object or nil if not found
    def self.find(id)
        row = db.execute('SELECT * FROM products WHERE id = ?', id).first
        return nil unless row

        # Translate the data types of certain fields
        row[4] = Time.iso8601(row[4]) if row[4]
        row[5] = Time.iso8601(row[5]) if row[5]
        row[6] = row[6] == 1 if row[6]
        row[7] = Time.iso8601(row[7]) if row[7]

        value = new(*row[1..-1])
        value.id = row[0]
        value
    end

    # Saves a single field of the Product object to the database.
    #
    # @param field [Symbol] the field name to be saved
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
        old_value = self.class.db.execute("SELECT #{field} FROM products WHERE id = ?", @id).flatten.first

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

        self.class.db.execute("UPDATE products SET #{field} = ? WHERE id = ?", new_value, @id)
    end

    # Inserts a new product record into the database.
    #
    # @return [void]
    def insert
        creation_date = @creation_date.iso8601
        expiration_date = @expiration_date.iso8601

        sold_date = nil
        sold_date = @sold_date.iso8601 if @sold_date.instance_of?(Time)

        is_sold = 0
        is_sold = 1 if @is_sold == true

        self.class.db.execute(
            'INSERT INTO products (id, user_id, title, description, creation_date, expiration_date, is_sold, sold_date, winner_user_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', @id, @user_id, @title, @description, creation_date, expiration_date, is_sold, sold_date, nil
        )
    end

    # Deletes the product from the database.
    #
    # @return [void]
    def destroy
        self.class.db.execute('DELETE FROM products WHERE id = ?', @id)
    end

    # Picks the winner of the product if it has not been sold and has a bid.
    #
    # @return [Boolean] true if a winner was successfully picked, false otherwise
    def pick_winner
        # Check if the product is sold
        return false if @is_sold

        # Check if the product has a bid
        bid = Bid.find_highest_bid(@id)
        return false unless bid

        # Pick a winner
        @winner_user_id = bid.user_id
        save_field(:winner_user_id)

        # Set is sold
        @is_sold = true
        save_field(:is_sold)

        @sold_date = Time.now
        save_field(:sold_date)

        true
    end
end
