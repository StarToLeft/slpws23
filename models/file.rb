require 'sqlite3'
require 'securerandom'

# The FileModel class represents a file in the database.
#
# @!attribute id
#   @return [String] the universally unique identifier (UUID) of the file
# @!attribute name
#   @return [String] the name of the file
# @!attribute extension
#   @return [String] the file extension
class FileModel
    attr_accessor :id, :name, :extension

    # Initializes a new FileModel instance with the given name and extension.
    #
    # @param name [String] the name of the file
    # @param extension [String] the file extension
    def initialize(name, extension)
        @id = SecureRandom.uuid
        @name = name
        @extension = extension
    end

    # @!visibility private
    def self.db
        unless defined?(@db)
            @db = SQLite3::Database.new('./db/marketplace.sqlite')
            @db.execute('PRAGMA foreign_keys = ON')
        end
        @db
    end

    # Finds a file by its ID.
    #
    # @param id [String] the UUID of the file to find
    # @return [FileModel, nil] the FileModel instance if found, or nil if not found
    def self.find(id)
        row = db.execute('SELECT * FROM files WHERE id = ?', id).first
        return nil unless row

        value = new(*row[1..-1])
        value.id = row[0]
        value
    end

    # Inserts the file into the database.
    #
    # @return [void]
    def insert
        self.class.db.execute(
            'INSERT INTO files (id, name, extension) VALUES (?, ?, ?)', @id, @name, @extension
        )
    end

    # Deletes the file from the database.
    #
    # @return [void]
    def destroy
        self.class.db.execute('DELETE FROM files WHERE id = ?', @id)
    end
end
