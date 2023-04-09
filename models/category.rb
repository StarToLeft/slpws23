require 'sqlite3'
require 'securerandom'

# The Category class represents a category in the database.
#
# @!attribute id
#   @return [String] the universally unique identifier (UUID) of the category
# @!attribute name
#   @return [String] the name of the category
class Category
    attr_accessor :id, :name

    # Initializes a new Category instance with the given name.
    #
    # @param name [String] the name of the category
    def initialize(name)
        @id = SecureRandom.uuid
        @name = name
    end

    # @!visibility private
    def self.db
        unless defined?(@db)
            @db = SQLite3::Database.new('./db/marketplace.sqlite')
            @db.execute('PRAGMA foreign_keys = ON')
        end
        @db
    end

    # Retrieves all categories from the database.
    #
    # @return [Array<Category>] an array of Category instances
    def self.all
        db.execute('SELECT * FROM categories').map do |row|
            value = new(*row[1..-1])
            value.id = row[0]
            value
        end
    end

    # Finds a category by its ID.
    #
    # @param id [String] the UUID of the category to find
    # @return [Category, nil] the Category instance if found, or nil if not found
    def self.find(id)
        row = db.execute('SELECT * FROM categories WHERE id = ?', id).first
        return nil unless row

        value = new(*row[1..-1])
        value.id = row[0]
        value
    end

    # Saves a specified field of the Category instance to the database.
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
        old_value = self.class.db.execute("SELECT #{field} FROM categories WHERE id = ?", @id).flatten.first

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

        self.class.db.execute("UPDATE categories SET #{field} = ? WHERE id = ?", new_value, @id)
    end

    # Inserts the category into the database.
    #
    # @return [void]
    def insert
        self.class.db.execute('INSERT INTO categories (id, name) VALUES (?, ?)', @id, @name)
    end

    # Deletes the category from the database.
    #
    # @return [void]
    def destroy
        self.class.db.execute('DELETE FROM categories WHERE id = ?', @id)
    end
end
