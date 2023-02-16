require 'sqlite3'
require 'securerandom'
require 'bcrypt'

class Product
    attr_accessor :id, :user_id, :title, :description, :creation_date, :expiration_date, :is_sold, :sold_date

    def initialize(user_id, title, description, creation_date, expiration_date, is_sold, sold_date)
        @id = SecureRandom.uuid
        @user_id = user_id
        @title = title
        @description = description
        @creation_date = creation_date
        @expiration_date = expiration_date
        @is_sold = is_sold
        @sold_date = sold_date
    end

    def self.db
        @db ||= SQLite3::Database.new('./db/marketplace.sqlite')
    end

    def self.find(id)
        row = db.execute('SELECT * FROM products WHERE id = ?', id).first
        return nil unless row

        user = new(*row[1..-1])
        user.id = row[0]
        user
    end

    def save_field(field)
        return if @id.nil?

        # Check if the field exists as a public attribute of the User class
        unless respond_to?(field)
            puts "Error: #{field} is not a valid field for the User class."
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

    def insert
        creation_date = @creation_date.iso8601
        expiration_date = @expiration_date.iso8601

        sold_date = nil
        sold_date = @sold_date.iso8601 if @sold_date.instance_of?(Time)

        is_sold = 0
        is_sold = 1 if @is_sold == true

        self.class.db.execute(
            'INSERT INTO products (id, user_id, title, description, creation_date, expiration_date, is_sold, sold_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', @id, @user_id, @title, @description, creation_date, expiration_date, is_sold, sold_date
        )
    end

    def destroy
        self.class.db.execute('DELETE FROM products WHERE id = ?', @id)
    end
end
