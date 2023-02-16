require 'bcrypt'

require_relative '../models/user'

module Authentication
    def self.authenticate(user, password)
        return true if BCrypt::Password.new(user.encrypted_password) == password

        false
    end

    def self.encrypt_password(password)
        BCrypt::Password.create(password)
    end
end
