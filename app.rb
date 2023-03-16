require 'sinatra'
require 'slim'
require 'sqlite3'

enable :sessions

require_relative 'models/user'
require_relative 'models/product'
require_relative 'models/bid'

require_relative 'backend/auth'
require_relative 'backend/product'

db = SQLite3::Database.new('./db/marketplace.sqlite')
db.execute('DELETE FROM bids')
db.execute('DELETE FROM products')
db.execute('DELETE FROM users')
db.execute('VACUUM')

get('/') do
    slim(:home)
end

get('/profile/:username') do
    user = User.find_by_username(params[:username])
    slim(:profile, locals: { user: user })
end

get('/login') do
    # Redirect to home page if user is already logged in
    # Replace with JWT
    if session[:user_id]
        redirect('/')
    else
        slim(:login, locals: { error: params[:error] })
    end
end

post('/login') do
    # TODO: add jwts (skip refresh tokens for now)

    user = User.find_by_username(params[:username])
    if user && Auth.authenticate(user, params[:password])
        session[:user_id] = user.id
        # TODO: replace user_id with token in session (json-web-token)

        redirect('/')
    else
        error = 'Invalid username or password'
        slim(:login, locals: { error: error })
    end
end

get('/logout') do
    session[:user_id] = nil
    redirect('/')
end

get('/register') do
    slim(:register, locals: { error: params[:error] })
end

post('/register') do
    # Password requirements
    password_regex = /\A(?=.{8,})(?=.*\d)(?=.*[a-z])(?=.*[A-Z])(?=.*[[:^alnum:]])/x
    unless password_regex.match?(params[:password])
        redirect("/register?error=#{URI.encode_www_form_component('Password does not meet requirements')}")
    end

    # Email check
    email_regex = /\A[\w+\-.]+@[a-z\d-]+(\.[a-z\d-]+)*\.[a-z]+\z/i
    unless email_regex.match?(params[:email])
        redirect("/register?error=#{URI.encode_www_form_component('Invalid email')}")
    end

    # Username check
    username_regex = /\A[a-zA-Z0-9]+\z/
    unless username_regex.match?(params[:username])
        redirect("/register?error=#{URI.encode_www_form_component('Invalid username')}")
    end

    # Type checks
    unless params[:username].is_a?(String) && params[:password].is_a?(String) && params[:email].is_a?(String)
        redirect("/register?error=#{URI.encode_www_form_component('Invalid input types')}")
    end

    # Check if account already exists
    if User.find_by_username(params[:username]) || User.find_by_email(params[:email])
        redirect("/register?error=#{URI.encode_www_form_component('Account already exists')}")
    end

    # Create new user and redirect to home page
    user = User.new(params[:username], Auth.encrypt_password(params[:password]), nil, Time.now, params[:email])
    user.insert
    redirect('/')
end

# Product
get('/product/:product_id') do
    product = Product.find(params[:product_id])
    puts product.inspect
    slim(:product, locals: { product: product })
end

post('/product') do
    # TODO: introduce type checks

    user = User.find(session[:user_id])
    creation_date = Time.now
    expiration_date = creation_date + (5 * 24 * 60 * 60)
    product = Product.new(user.id, params[:title], params[:description], creation_date, expiration_date, false, nil,
                          nil)
    product.insert
    redirect('/')
end
