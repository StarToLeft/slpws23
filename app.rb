# require 'sinatra'
# require 'slim'
require 'sqlite3'

require_relative 'models/user'
require_relative 'models/product'

require_relative 'backend/auth'

db = SQLite3::Database.new('./db/marketplace.sqlite')
db.execute('DELETE FROM users')
db.execute('DELETE FROM products')
db.execute('VACUUM')

user = User.new('StarToLeft', Authentication.encrypt_password('sdn72@£x81'), nil, Time.now, 'anton.hagser@epsidel.se')
user.insert

puts 'Authentication result: ' + Authentication.authenticate(user, 'sdn72@£x81').to_s
puts 'Authentication result: ' + Authentication.authenticate(user, 'sdn72@£x82').to_s

creation_date = Time.now
expiration_date = creation_date + (5 * 24 * 60 * 60)
product = Product.new(user.id, 'Test', 'This is a test', creation_date, expiration_date, false, nil)
product.insert

product1 = Product.find(product.id)
puts product1.title

user1 = User.find(user.id)
puts user1.username

# get('/get') do
#     slim(:home)
# end
