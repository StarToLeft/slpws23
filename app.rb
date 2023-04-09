require 'sinatra'
require 'rack/protection'
require 'slim'
require 'sqlite3'

enable :sessions
set :session_fail, '/login'
set :session_secret, '293068d1ea7e016b1c47c13c0678feba9a406b49bf78c46ae2c009900542bf5a'
set :session_encrypted, true

require_relative 'models/user'
require_relative 'models/product'
require_relative 'models/bid'
require_relative 'models/file'
require_relative 'models/media'
require_relative 'models/category'

require_relative 'backend/auth'
require_relative 'backend/product'

# use Rack::Protection

configure do
    use Rack::Protection::FormToken
end

# Store failed login attempts
$failed_login_attempts = {}

# Define helper methods for the application
helpers do
    # Get the current user based on the session token.
    #
    # @return [User, nil] the current User if logged in, nil if not logged in
    def current_user
        return nil unless session[:token]

        jwt_validation_result = Auth.validate_jwt(session[:token])
        return nil unless jwt_validation_result && jwt_validation_result[:valid]

        user_id = Auth.get_id(session[:token])
        user = User.find(user_id)
        return nil unless user

        user
    end

    # Check if a user is logged in.
    #
    # @return [Boolean] true if a user is logged in, false otherwise
    def is_logged_in
        !!current_user
    end

    # Check if a user is an administrator.
    #
    # @return [Boolean] true if the user is an admin, false otherwise
    def is_admin
        return false unless is_logged_in

        current_user.is_admin
    end
end

# Route definitions
# Common for all routes is the use of session[:token] which contains a JWT when the user is signed in
# The JWT contains the user ID and a expiration time, it is used to identify the user

# Display the home page with a list of products
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

# Display the current user's account page
get('/accounts/me') do
    # Check if user is logged in with helper method
    redirect('/login') unless is_logged_in
    user = current_user

    products = Product.find_by_user_id(user.id)
    won_products = Product.find_by_winner_user_id(user.id)

    slim(:'accounts/me', locals: { user: user, products: products, won_products: won_products })
end

# Displays the edit account page
get('/accounts/edit') do
    # Check if user is logged in with helper method
    redirect('/login') unless is_logged_in
    user = current_user

    slim(:'accounts/edit', locals: { user: user, success: params[:success], error: params[:error] })
end

# Handles the edit account form
post('/accounts/edit') do
    # Check if user is logged in with helper method
    redirect('/login') unless is_logged_in
    user = current_user

    # check if username and email are given
    if params[:username].empty? || params[:email].empty?
        redirect("/accounts/edit?error=#{URI.encode_www_form_component('Please fill in all fields!')}")
    end

    user_by_username = User.find_by_username(params[:username])
    if user_by_username && user_by_username.id != user.id
        redirect("/accounts/edit?error=#{URI.encode_www_form_component('Username already taken!')}")
    end

    # Email regex check (not perfect, but good enough for this project)
    email_regex = /\A[\w+\-.]+@[a-z\d-]+(\.[a-z\d-]+)*\.[a-z]+\z/i
    unless email_regex.match?(params[:email])
        redirect("/accounts/edit?error=#{URI.encode_www_form_component('Invalid email')}")
    end

    user_by_email = User.find_by_email(params[:email])
    if user_by_email && user_by_email.id != user.id
        redirect("/accounts/edit?error=#{URI.encode_www_form_component('Email already taken!')}")
    end

    user.username = params[:username]
    user.email = params[:email]

    user.save_field(:username)
    user.save_field(:email)

    redirect("/accounts/edit?success=#{URI.encode_www_form_component('Successfully updated your account information!')}")
end

# Display another user's account page
get('/accounts/:username') do
    user = User.find_by_username(params[:username])
    redirect('/accounts/me') if (is_logged_in && user.nil?) || user.id == Auth.get_id(session[:token])

    won_products = Product.find_by_winner_user_id(user.id)
    slim(:'accounts/info', locals: { user: user, won_products: won_products })
end

# Display the admin user management page
get('/admin/users') do
    # Check if user is logged in
    redirect('/login') unless is_admin

    users = User.all

    slim(:'admin/users', locals: { users: users })
end

# Delete a user by user_id
post('/admin/users/:user_id/delete') do
    # Check if user is logged in and admin with helper method
    redirect('/login') unless is_admin

    user_id = params[:user_id]
    user = User.find(user_id)
    user.destroy

    redirect('/admin/users')
end

# Toggle the admin status of a user by user_id
post('/admin/users/:user_id/toggle-admin') do
    # Check if user is admin
    redirect('/login') unless is_admin

    user_id = params[:user_id]
    user = User.find(user_id)
    user.is_admin = !(user.is_admin == true)

    user.save_field(:is_admin)

    redirect('/admin/users')
end

# Display the admin product management page
get('/admin/products') do
    # Check if user is logged in and admin with helper method
    redirect('/login') unless is_admin

    dbProducts = Product.all

    products = []
    dbProducts.each do |product|
        if product.winner_user_id
            winner = User.find(product.winner_user_id)
            products << { product: product, winner: winner }
        else
            products << { product: product, winner: nil }
        end
    end

    slim(:'admin/products', locals: { products: products })
end

# Delete a product by product_id
post('/admin/products/:product_id/delete') do
    # Check if user is logged in and admin with helper method
    redirect('/login') unless is_admin

    product_id = params[:product_id]
    product = Product.find(product_id)
    product.destroy

    redirect('/admin/products')
end

# Pick a winner for a product by product_id
post('/admin/products/:product_id/pick-winner') do
    # Check if user is logged in and admin with helper method
    redirect('/login') unless is_admin

    product_id = params[:product_id]
    product = Product.find(product_id)

    # Check if winner has already been picked
    redirect('/admin/products') if product.winner_user_id

    product.pick_winner

    redirect('/admin/products')
end

# Display the admin category management page
get('/admin/categories') do
    # Check if user is logged in and admin with helper method
    redirect('/login') unless is_admin

    categories = Category.all

    slim(:'admin/categories', locals: { categories: categories, success: params[:success], error: params[:error] })
end

# Delete a category by category_id
post('/admin/categories/:category_id/delete') do
    # Check if user is logged in and admin with helper method
    redirect('/login') unless is_admin

    category_id = params[:category_id]
    category = Category.find(category_id)
    category.destroy

    redirect('/admin/categories')
end

# Display the new category creation page
get('/admin/categories/new') do
    # Check if user is logged in and admin with helper method
    redirect('/login') unless is_admin

    slim(:'admin/categories/new')
end

# Create a new category
post('/admin/categories') do
    # Check if user is logged in and admin with helper method
    redirect('/login') unless is_admin

    category = Category.new(params[:name])
    category.insert

    redirect('/admin/categories?success=Category created')
end

# Route for the login page.
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

# Route for submitting login credentials.
post('/login') do
    ip = request.ip # Get the IP address of the client
    current_time = Time.now

    # Clean up old failed attempts
    $failed_login_attempts.delete_if { |_key, value| value[:last_attempt] < current_time - 60 }

    # Check if there have been 3 failed attempts in the last minute from this IP
    if $failed_login_attempts[ip] && $failed_login_attempts[ip][:count] >= 3 && $failed_login_attempts[ip][:last_attempt] > current_time - 60
        error = 'Too many login attempts. Please wait 1 minute before trying again.'
        slim(:login, locals: { error: error })
    else
        user = User.find_by_username(params[:username])

        if user && Auth.authenticate(user, params[:password])
            token = Auth.create_jwt(user.id)
            session[:token] = token

            # Clear failed login attempts for this IP
            $failed_login_attempts.delete(ip)

            redirect('/')
        else
            error = 'Invalid username or password'

            # Increment the failed login attempts for this IP
            if $failed_login_attempts[ip]
                $failed_login_attempts[ip][:count] += 1
                $failed_login_attempts[ip][:last_attempt] = current_time
            else
                $failed_login_attempts[ip] = { count: 1, last_attempt: current_time }
            end

            slim(:login, locals: { error: error })
        end
    end
end

# Route for logging out the current user.
get('/logout') do
    session[:token] = nil
    redirect('/')
end

# Route for the registration page.
get('/register') do
    slim(:register, locals: { error: params[:error], success: params[:success] })
end

# Route for submitting registration details.
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

# Route for the page to create a new product.
get('/products/new') do
    # Check if user is logged in
    redirect('/login') unless is_logged_in

    # current_date as format yyyy-mm-dd (derived from current time + 1 day)
    current_date = (Time.now + 86_400).strftime('%Y-%m-%d')
    current_time = Time.now.strftime('%H:%M')

    # Get categories
    categories = Category.all

    slim(:'products/new', locals: { current_date: current_date, current_time: current_time, categories: categories })
end

# Route for the individual product page.
get('/products/:product_id') do
    product = Product.find(params[:product_id])
    product = Product.find(params[:product_id]) if ProductManager.check_product_state(product.id) == true

    winner = User.find(product.winner_user_id) if product.winner_user_id

    db = Bid.db
    db.execute("PRAGMA foreign_keys = ON")
    db_bids = db.execute(
        'SELECT amount, username FROM bids INNER JOIN users ON bids.user_id = users.id WHERE bids.product_id=?', product.id
    )

    bids = []
    for db_bid in db_bids
        bids.append({ amount: db_bid[0], username: db_bid[1] })
    end

    current_bid_price = bids[0][:amount].to_f if bids.length > 0

    # Check if product has media
    media = Media.find_by_product_id(product.id)

    # We only support one image per product for now
    firstMedia = media[0] if media

    # Get extension
    extension = FileModel.find(firstMedia.file_id).extension if firstMedia

    # List of all categories assigned to product
    db = Bid.db
    db.execute("PRAGMA foreign_keys = ON")
    db_categories = db.execute(
        'SELECT name FROM product_category_rel INNER JOIN categories ON product_category_rel.category_id = categories.id WHERE product_category_rel.product_id=?', product.id
    )

    categories = []
    for db_category in db_categories
        categories.append(db_category[0])
    end

    slim(:'products/product',
         locals: { product: product, bids: bids, current_bid_price: current_bid_price, winner: winner, error: params[:error],
                   success: params[:success], media: firstMedia, extension: extension, categories: categories })
end

# Route for creating a new product.
post('/products') do
    # Check if user is logged in
    redirect('/login') unless is_logged_in

    user = current_user
    creation_date = Time.now

    # Get expiration date from params expiration_date (yyyy-mm-dd) and expiration_time (hh::mm)
    expiration_date = Time.parse("#{params[:expiration_date]} #{params[:expiration_time]}")
    product = Product.new(user.id, params[:title], params[:description], creation_date, expiration_date, false, nil,
                          nil)
    product.insert

    # Add image to product
    if params[:image] && params[:image][:filename]
        filename = params[:image][:filename]
        file = params[:image][:tempfile]
        extension = filename.split('.').last

        # Add file to database
        fileModel = FileModel.new(filename, extension)
        fileModel.insert

        path = "./public/uploads/#{fileModel.id}.#{extension}"

        # Add file to product
        media = Media.new(user.id, fileModel.id, product.id)
        media.insert

        File.open(path, 'wb') do |f|
            f.write(file.read)
        end
    end

    db = Bid.db

    # Add categories to product
    if params[:categories] && params[:categories].length > 0
        for category in params[:categories]
            # Check if category exists and add it to product_category_rel if it does
            category = Category.find(category)
            unless category.nil?
                db.execute('INSERT INTO product_category_rel (id, product_id, category_id) VALUES (?, ?, ?)',
                           SecureRandom.uuid, product.id, category.id)
            end
        end
    end

    redirect('/')
end

# Route for the page to place a bid on a product.
get('/products/:product_id/bid') do
    # Check if user is logged in
    redirect('/login') unless is_logged_in

    product = Product.find(params[:product_id])
    slim(:'products/bids/new', locals: { product: product })
end

# Route for submitting a bid on a product.
post('/products/:product_id/bid') do
    # Check if user is logged in
    redirect('/login') unless is_logged_in

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
