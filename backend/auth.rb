require 'bcrypt'
require 'jwt'

require_relative '../models/user'

# A module for handling authentication and authorization in the application.
module Auth
    # A secret key for signing JSON Web Tokens (JWTs).
    SECRET_KEY = 'super-secret-key-som-ingen-knows'

    # Authenticates a user by comparing an encrypted password with a provided password.
    #
    # @param user [User] the user to authenticate
    # @param password [String] the password to compare with the encrypted password
    # @return [Boolean] true if the password matches, false otherwise
    def self.authenticate(user, password)
        return true if BCrypt::Password.new(user.encrypted_password) == password

        false
    end

    # Encrypts a password using BCrypt.
    #
    # @param password [String] the password to encrypt
    # @return [BCrypt::Password] the encrypted password
    def self.encrypt_password(password)
        BCrypt::Password.create(password)
    end

    # Creates a JSON Web Token (JWT) for a user ID.
    #
    # @param user_id [Integer] the user ID to include in the JWT
    # @return [String] the JWT
    def self.create_jwt(user_id)
        payload = { user_id: user_id, exp: (Time.now + 24 * 60 * 60).to_i }
        JWT.encode(payload, SECRET_KEY, 'HS256')
    end

    # Validates a JWT and returns the user ID if the token is valid.
    #
    # @param token [String] the JWT to validate
    # @return [Hash] a hash containing :valid and :user_id keys
    def self.validate_jwt(token)
        decoded_token = JWT.decode(token, SECRET_KEY, true, { algorithm: 'HS256' })
        { valid: true, user_id: decoded_token[0]['user_id'] }
    rescue JWT::DecodeError
        { valid: false }
    end

    # Retrieves the user ID from a valid JWT.
    #
    # @param token [String] the JWT
    # @return [Integer] the user ID from the JWT
    def self.get_id(token)
        decoded_token = JWT.decode(token, SECRET_KEY, true, { algorithm: 'HS256' })
        decoded_token[0]['user_id']
    end
end
