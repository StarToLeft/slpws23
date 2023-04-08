require 'sinatra'
require 'slim'
require 'sqlite3'

enable :sessions

require_relative 'models/user'
require_relative 'models/product'
require_relative 'models/bid'

require_relative 'backend/auth'
require_relative 'backend/product'

get('/') do
    # Get all products
    products = Product.all

    # Get winners of products
    product_placements = []
    products.each do |product|
        if product.is_sold && product.winner_user_id
            winner = User.find(product.winner_user_id)
            product_placements << { product: product, winner: winner }
        else
            product_placements << { product: product, winner: nil }
        end
    end

    slim(:index, locals: { product_placements: product_placements })
end

get('/accounts/me') do
    user_id = Auth.get_id(session[:token])
    user = User.find(user_id)
    products = Product.find_by_user_id(user.id)
    slim(:'accounts/me', locals: { user: user, products: products })
end

get('/accounts/:username') do
    puts params[:username]

    user = User.find_by_username(params[:username])
    won_products = Product.find_by_winner_user_id(user.id)

    slim(:'accounts/info', locals: { user: user, won_products: won_products })
end

get('/login') do
    # Replace with JWT validation
    jwt_validation_result = Auth.validate_jwt(session[:token]) if session[:token]

    # Redirect to home page if user is already logged in and JWT is valid
    if jwt_validation_result && jwt_validation_result[:valid]
        redirect('/')
    else
        slim(:login, locals: { error: params[:error] })
    end
end

post('/login') do
    user = User.find_by_username(params[:username])

    if user && Auth.authenticate(user, params[:password])
        token = Auth.create_jwt(user.id)
        session[:token] = token

        redirect('/')
    else
        error = 'Invalid username or password'
        slim(:login, locals: { error: error })
    end
end

get('/logout') do
    session[:token] = nil
    redirect('/')
end

get('/register') do
    slim(:register, locals: { error: params[:error], success: params[:success] })
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
    redirect("/register?success=#{URI.encode_www_form_component('Account created successfully')}")
end

get('/products/new') do
    slim(:'products/new')
end

get('/products/:product_id') do
    product = Product.find(params[:product_id])
    product = Product.find(params[:product_id]) if ProductManager.check_product_state(product.id) == true

    winner = User.find(product.winner_user_id) if product.winner_user_id

    db = Bid.db
    db_bids = db.execute(
        'SELECT amount, username FROM bids INNER JOIN users ON bids.user_id = users.id WHERE bids.product_id=?', product.id
    )

    bids = []
    for db_bid in db_bids
        bids.append({ amount: db_bid[0], username: db_bid[1] })
    end

    current_bid_price = bids[0][:amount].to_f if bids.length > 0

    slim(:'products/product',
         locals: { product: product, bids: bids, current_bid_price: current_bid_price, winner: winner, error: params[:error],
                   success: params[:success] })
end

post('/products') do
    # TODO: introduce type checks
    # TODO: get id from token

    user_id = Auth.get_id(session[:token])

    user = User.find(user_id)
    creation_date = Time.now
    expiration_date = creation_date + (5 * 24 * 60 * 60)
    product = Product.new(user.id, params[:title], params[:description], creation_date, expiration_date, false, nil,
                          nil)
    product.insert

    redirect('/')
end

get('/products/:product_id/bid') do
    product = Product.find(params[:product_id])
    slim(:'products/bid', locals: { product: product })
end

post('/products/:product_id/bid') do
    user_id = Auth.get_id(session[:token])
    product_id = params[:product_id]

    # Try to place bid
    result = ProductManager.place_bid(user_id, product_id, params[:amount].to_i)
    if result[0]
        redirect("/products/#{product_id}?success=#{URI.encode_www_form_component(result[1])}")
    else
        redirect("/products/#{product_id}?error=#{URI.encode_www_form_component(result[1])}")
    end
end
