require 'sqlite3'
require 'securerandom'
require 'bcrypt'

class User
    attr_accessor :id, :username, :encrypted_password, :pfp_file_id, :creation_date, :email

    def initialize(username, encrypted_password, pfp_file_id, creation_date, email)
        @id = SecureRandom.uuid
        @username = username
        @encrypted_password = encrypted_password
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
        creation_date = @creation_date.iso8601

        self.class.db.execute(
            'INSERT INTO users (id, username, password, pfp_file_id, creation_date, email) VALUES (?, ?, ?, ?, ?, ?)', @id, @username, @encrypted_password, @pfp_file_id, creation_date, @email
        )
    end

    def destroy
        self.class.db.execute('DELETE FROM users WHERE id = ?', @id)
    end
end
