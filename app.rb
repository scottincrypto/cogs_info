require 'sinatra'
require 'httparty'
require 'json'
require 'date'
require 'fileutils'

# WooCommerce API settings
WC_API_BASE_URL = "https://www.softcogsinc.com/wp-json/wc/v3"
WC_CONSUMER_KEY = ENV['WOOCOMMERCE_CONSUMER_KEY']
WC_CONSUMER_SECRET = ENV['WOOCOMMERCE_CONSUMER_SECRET']

# Filesystem cache settings
CACHE_DIR = File.join(Dir.tmpdir, 'wc_api_cache')
CACHE_EXPIRATION = 3600 # Cache expiration time in seconds (1 hour)

FileUtils.mkdir_p(CACHE_DIR) unless File.directory?(CACHE_DIR)

# Modified helper method to include filesystem caching
def wc_api_request(endpoint, params = {})
  cache_key = Digest::MD5.hexdigest("#{endpoint}:#{params.to_json}")
  cache_file = File.join(CACHE_DIR, cache_key)

  if File.exist?(cache_file) && File.mtime(cache_file) > Time.now - CACHE_EXPIRATION
    JSON.parse(File.read(cache_file))
  else
    url = "#{WC_API_BASE_URL}/#{endpoint}"
    auth = { consumer_key: WC_CONSUMER_KEY, consumer_secret: WC_CONSUMER_SECRET }
    response = HTTParty.get(url, query: params.merge(auth))
    parsed_response = JSON.parse(response.body)
    
    File.write(cache_file, parsed_response.to_json)
    parsed_response
  end
end

get '/' do
  @products = wc_api_request('products', per_page: 10)
  erb :index
end

get '/orders' do
  cutoff_date = Date.parse('2024-09-22')
  @orders = []
  page = 1
  per_page = 100

  loop do
    orders_page = wc_api_request('orders', per_page: per_page, page: page)
    break if orders_page.empty?

    filtered_orders = orders_page.select { |order| Date.parse(order['date_created']) > cutoff_date }
    @orders.concat(filtered_orders)
    
    break if Date.parse(orders_page.last['date_created']) <= cutoff_date
    page += 1
  end

  @orders.each do |order|
    # Add order status
    order['status'] = order['status']

    # Set customer information
    order['customer'] = {
      'name' => "#{order['billing']['first_name']} #{order['billing']['last_name']}".strip,
      'email' => order['billing']['email']
    }

    # Fetch customer details if customer_id exists
    customer_id = order['customer_id']
    if customer_id && customer_id != 0
      customer = wc_api_request("customers/#{customer_id}")
      if customer && !customer.empty?
        order['customer']['name'] = customer['first_name'] + ' ' + customer['last_name']
        order['customer']['email'] = customer['email']
      end
    end
    
    # If no customer data, use billing info
    if !order['customer'] || order['customer'].empty?
      order['customer'] = {
        'name' => "#{order['billing']['first_name']} #{order['billing']['last_name']}".strip,
        'email' => order['billing']['email']
      }
    end
    
    # Fetch line items details
    order['line_items'].each do |item|
      product_id = item['product_id']
      if product_id
        product = wc_api_request("products/#{product_id}")
        item['product'] = product if product
        
        # Add variant information
        if item['variation_id'] && item['variation_id'] != 0
          variation = wc_api_request("products/#{product_id}/variations/#{item['variation_id']}")
          item['variant'] = variation if variation
        end
      end
    end
  end
  erb :orders
end

get '/customers' do
  @customers = wc_api_request('customers', per_page: 20)
  erb :customers
end

# Route for product orders
get '/product/:id' do
  product_id = params[:id]
  @product_name = wc_api_request("products/#{product_id}")['name']
  
  cutoff_date = Date.parse('2024-09-22')
  @orders = []
  page = 1
  per_page = 100

  loop do
    orders_page = wc_api_request('orders', per_page: per_page, page: page)
    break if orders_page.empty?

    filtered_orders = orders_page.select do |order|
      Date.parse(order['date_created']) > cutoff_date &&
      order['line_items'].any? { |item| item['product_id'].to_s == product_id }
    end

    filtered_orders.each do |order|
      customer_info = {
        'name' => "#{order['billing']['first_name']} #{order['billing']['last_name']}".strip,
        'email' => order['billing']['email']
      }

      # Fetch customer details if customer_id exists
      if order['customer_id'] && order['customer_id'] != 0
        customer = wc_api_request("customers/#{order['customer_id']}")
        if customer && !customer.empty?
          customer_info['name'] = "#{customer['first_name']} #{customer['last_name']}".strip
          customer_info['email'] = customer['email']
        end
      end

      # Find the relevant line item and extract variant information
      line_item = order['line_items'].find { |item| item['product_id'].to_s == product_id }
      variant_info = nil
      if line_item && line_item['variation_id'] && line_item['variation_id'] != 0
        variant = wc_api_request("products/#{product_id}/variations/#{line_item['variation_id']}")
        if variant && !variant.empty?
          variant_info = variant['attributes'].map { |attr| attr['option'] }.join(', ')
        end
      end

      @orders << {
        'id' => order['id'],
        'customer' => customer_info,
        'status' => order['status'],
        'date' => order['date_created'],
        'variant' => variant_info
      }
    end
    
    break if Date.parse(orders_page.last['date_created']) <= cutoff_date
    page += 1
  end

  erb :product_orders
end
