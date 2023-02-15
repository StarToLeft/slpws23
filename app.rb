# require 'sinatra'
# require 'slim'
require 'sqlite3'

require_relative 'models/user'

user = User.new('test', 'test', 'test', 'test', 'test')
user.insert

user.username = 'test3'
user.save_field(:username)

user.destroy

# get('/get') do
#     slim(:home)
# end
