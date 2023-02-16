require 'sqlite3'
require 'securerandom'

class Category
    attr_accessor :id, :name, :description

    def initialize(_id, name, description)
        @id = SecureRandom.uuid
        @name = name
        @description = description
    end

    def self.db
        @db ||= SQLite3::Database.new('./db/marketplace.sqlite')
    end

    def self.find(id)
        row = db.execute('SELECT * FROM categories WHERE id = ?', id).first
        return nil unless row

        value = new(*row[1..-1])
        value.id = row[0]
        value
    end

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

    def insert
        self.class.db.execute('INSERT INTO categories (id, name, description) VALUES (?, ?, ?)', @id, @name,
                              @description)
    end

    def destroy
        self.class.db.execute('DELETE FROM categories WHERE id = ?', @id)
    end
end
