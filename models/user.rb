require 'sqlite3'
require 'securerandom'

class User
    attr_accessor :id, :username, :password, :pfp_file_id, :creation_date, :email

    def initialize(username, password, pfp_file_id, creation_date, email)
        @id = SecureRandom.uuid
        @username = username
        @password = password
        @pfp_file_id = pfp_file_id
        @creation_date = creation_date
        @email = email
    end

    def self.db
        @db ||= SQLite3::Database.new('./db/marketplace.sqlite')
    end

    def self.find(id)
        row = db.execute('SELECT * FROM users WHERE id = ?', id).first
        return nil unless row

        user = new(*row[1..-1])
        user.id = row[0]
        user
    end

    def self.find_by_username(username)
        row = db.execute('SELECT * FROM users WHERE username = ?', username).first
        return nil unless row

        user = new(*row[1..-1])
        user.id = row[0]
        user
    end

    def self.find_by_email(email)
        row = db.execute('SELECT * FROM users WHERE email = ?', email).first
        return nil unless row

        user = new(*row[1..-1])
        user.id = row[0]
        user
    end

    # Saves the current User object to the database, updating only the fields that have changed.
    # Usage: user.save_field(:username)
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

        new_value = send(field)
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

    def insert
        self.class.db.execute(
            'INSERT INTO users (id, username, password, pfp_file_id, creation_date, email) VALUES (?, ?, ?, ?, ?, ?)', @id, @username, @password, @pfp_file_id, @creation_date, @email
        )
    end

    def destroy
        self.class.db.execute('DELETE FROM users WHERE id = ?', @id)
    end
end
