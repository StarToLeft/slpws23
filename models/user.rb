require 'sqlite3'
require 'securerandom'
require 'bcrypt'

# The User class represents a user in the system.
# It provides methods to interact with the SQLite database to store and retrieve user information.
class User
    # @!attribute [rw] id
    #   @return [String] the unique identifier for the user
    # @!attribute [rw] username
    #   @return [String] the username of the user
    # @!attribute [rw] encrypted_password
    #   @return [String] the encrypted password of the user
    # @!attribute [rw] pfp_file_id
    #   @return [String] the profile picture file identifier of the user
    # @!attribute [rw] creation_date
    #   @return [Time] the creation date of the user
    # @!attribute [rw] email
    #   @return [String] the email address of the user
    # @!attribute [rw] is_admin
    #   @return [Boolean] whether the user is an administrator
    attr_accessor :id, :username, :encrypted_password, :pfp_file_id, :creation_date, :email, :is_admin

    # Initializes a new User object.
    #
    # @param username [String] the username of the user
    # @param encrypted_password [String] the encrypted password of the user
    # @param pfp_file_id [String] the profile picture file identifier of the user
    # @param creation_date [Time] the creation date of the user
    # @param email [String] the email address of the user
    # @param is_admin [Boolean] whether the user is an administrator (defaults to false)
    def initialize(username, encrypted_password, pfp_file_id, creation_date, email, is_admin = false)
        @id = SecureRandom.uuid
        @username = username
        @encrypted_password = encrypted_password
        @pfp_file_id = pfp_file_id
        @creation_date = creation_date
        @email = email
        @is_admin = is_admin
    end

    # @!visibility private
    def self.db
        unless defined?(@db)
            @db = SQLite3::Database.new('./db/marketplace.sqlite')
            @db.execute('PRAGMA foreign_keys = ON')
        end
        @db
    end

    # Retrieves all users from the database.
    #
    # @return [Array<User>] an array of User objects
    def self.all
        db.execute('SELECT * FROM users').map do |row|
            user = new(*row[1..-1])
            user.id = row[0]
            user.is_admin = row[6] == 1
            user
        end
    end

    # Finds a user by their ID.
    #
    # @param id [String] the unique identifier of the user
    # @return [User, nil] the User object or nil if not found
    def self.find(id)
        row = db.execute('SELECT * FROM users WHERE id = ?', id).first
        return nil unless row

        user = new(*row[1..-1])
        user.id = row[0]
        user.is_admin = row[6] == 1
        user
    end

    # Finds a user by their username.
    #
    # @param username [String] the username of the user
    # @return [User, nil] the User object or nil if not found
    def self.find_by_username(username)
        row = db.execute('SELECT * FROM users WHERE username = ?', username).first
        return nil unless row

        user = new(*row[1..-1])
        user.id = row[0]
        user.is_admin = row[6] == 1
        user
    end

    # Finds a user by their email address.
    #
    # @param email [String] the email address of the user
    # @return [User, nil] the User object or nil if not found
    def self.find_by_email(email)
        row = db.execute('SELECT * FROM users WHERE email = ?', email).first
        return nil unless row

        user = new(*row[1..-1])
        user.id = row[0]
        user.is_admin = row[6] == 1
        user
    end

    # Saves a single field of the User object to the database.
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
        old_value = self.class.db.execute("SELECT #{field} FROM users WHERE id = ?", @id).flatten.first

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

        self.class.db.execute("UPDATE users SET #{field} = ? WHERE id = ?", new_value, @id)
    end

    # Inserts a new user record into the database.
    #
    # @return [void]
    def insert
        creation_date = @creation_date.iso8601
        is_admin = @is_admin ? 1 : 0

        self.class.db.execute(
            'INSERT INTO users (id, username, password, pfp_file_id, creation_date, email, is_admin) VALUES (?, ?, ?, ?, ?, ?, ?)', @id, @username, @encrypted_password, @pfp_file_id, creation_date, @email, is_admin
        )
    end

    # Deletes a user record from the database.
    #
    # @return [void]
    def destroy
        self.class.db.execute('DELETE FROM users WHERE id = ?', @id)
    end
end
