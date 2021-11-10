# frozen_string_literal: true

class Rack::Remote
  class Railtie < ::Rails::Railtie
    initializer 'rack-remote.middleware' do |app|
      app.config.middleware.use Rack::Remote unless Rails.env.production?
    end
  end
end
