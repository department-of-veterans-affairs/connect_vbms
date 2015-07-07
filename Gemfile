source 'https://rubygems.org'

gem 'httpi'
gem 'nokogiri'
gem 'xmlenc'

# to install without postgres, "bundle install --without postgres"
group :postgres do
  gem 'pg'
end

group :development do
  gem 'byebug'
  gem 'pry-nav'
end

group :development, :test do
  gem 'rspec'
  gem 'equivalent-xml'
end
