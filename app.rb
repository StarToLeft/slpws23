require 'sinatra'
require 'slim'
require 'sqlite3'

get('/') do
  slim(:home)
end
