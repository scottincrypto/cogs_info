require 'sinatra'
require 'woocommerce_api'

# Initialize WooCommerce API client
woocommerce = WooCommerce::API.new(
  # ENV['WOOCOMMERCE_URL'],
  "https://www.softcogsinc.com",
  ENV['WOOCOMMERCE_CONSUMER_KEY'],
  ENV['WOOCOMMERCE_CONSUMER_SECRET'],
  wp_api: true,
  version: 'wc/v3'
)

get '/' do
  @products = woocommerce.get('products').parsed_response
  # puts "Products:"
  # p @products
  erb :index
end

get '/orders' do
  @orders = woocommerce.get('orders').parsed_response
  erb :orders
end

get '/customers' do
  @customers = woocommerce.get('customers').parsed_response
  erb :customers
end
