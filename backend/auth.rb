require 'bcrypt'
require 'jwt'

require_relative '../models/user'

module Auth
    SECRET_KEY = 'super-secret-key-som-ingen-knows'

    def self.authenticate(user, password)
        return true if BCrypt::Password.new(user.encrypted_password) == password

        false
    end

    def self.encrypt_password(password)
        BCrypt::Password.create(password)
    end

    def self.create_jwt(user_id)
        payload = { user_id: user_id, exp: (Time.now + 24 * 60 * 60).to_i }
        JWT.encode(payload, SECRET_KEY, 'HS256')
    end

    def self.validate_jwt(token)
        decoded_token = JWT.decode(token, SECRET_KEY, true, { algorithm: 'HS256' })
        { valid: true, user_id: decoded_token[0]['user_id'] }
    rescue JWT::DecodeError
        { valid: false }
    end

    def self.get_id(token)
        decoded_token = JWT.decode(token, SECRET_KEY, true, { algorithm: 'HS256' })
        decoded_token[0]['user_id']
    end
end
