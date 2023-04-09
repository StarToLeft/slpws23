require 'sqlite3'
require 'securerandom'

# The Media class represents a media object in the database.
#
# @!attribute id
#   @return [String] the universally unique identifier (UUID) of the media object
# @!attribute user_id
#   @return [Integer] the user ID associated with the media object
# @!attribute file_id
#   @return [Integer] the file ID associated with the media object
# @!attribute product_id
#   @return [Integer] the product ID associated with the media object
class Media
    attr_accessor :id, :user_id, :file_id, :product_id

    # Initializes a new Media instance with the given user ID, file ID, and product ID.
    #
    # @param user_id [Integer] the user ID
    # @param file_id [Integer] the file ID
    # @param product_id [Integer] the product ID
    def initialize(user_id, file_id, product_id)
        @id = SecureRandom.uuid
        @user_id = user_id
        @file_id = file_id
        @product_id = product_id
    end

    # @!visibility private
    def self.db
        unless defined?(@db)
            @db = SQLite3::Database.new('./db/marketplace.sqlite')
            @db.execute('PRAGMA foreign_keys = ON')
        end
        @db
    end

    # Finds a media object by its ID.
    #
    # @param id [String] the UUID of the media object to find
    # @return [Media, nil] the Media instance if found, or nil if not found
    def self.find(id)
        row = db.execute('SELECT * FROM media WHERE id = ?', id).first
        return nil unless row

        value = new(*row[1..-1])
        value.id = row[0]
        value
    end

    # Finds media objects by their associated product ID.
    #
    # @param product_id [Integer] the product ID to find media objects for
    # @return [Array<Media>] an array of Media instances
    def self.find_by_product_id(product_id)
        rows = db.execute('SELECT * FROM media WHERE product_id = ?', product_id)

        rows.map do |row|
            value = new(*row[1..-1])
            value.id = row[0]
            value
        end
    end

    # Finds media objects by their associated user ID.
    #
    # @param user_id [Integer] the user ID to find media objects for
    # @return [Array<Media>] an array of Media instances
    def self.find_by_user_id(user_id)
        rows = db.execute('SELECT * FROM media WHERE user_id = ?', user_id)

        rows.map do |row|
            value = new(*row[1..-1])
            value.id = row[0]
            value
        end
    end

    # Inserts the media object into the database.
    #
    # @return [void]
    def insert
        self.class.db.execute(
            'INSERT INTO media (id, user_id, file_id, product_id) VALUES (?, ?, ?, ?)', @id, @user_id, @file_id, @product_id
        )
    end

    # Deletes the media object from the database.
    #
    # @return [void]
    def destroy
        self.class.db.execute('DELETE FROM media WHERE id = ?', @id)
    end
end
