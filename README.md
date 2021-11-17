# Rack::Remote

*Rack::Remote* is a small request intercepting Rack middleware to invoke
remote calls over HTTP. This can be used to invoke e.g. factories on
remote services for running integration tests on distributed applications.

## Installation

Add this line to your application's Gemfile:

    gem 'rack-remote'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rack-remote

## Usage

### On server/service side

Register available remote calls:

```ruby
Rack::Remote.register :factory_bot do |params, env, request|
  FactoryBot.create params[:factory]
end
```

Return value can be a Rack response array or any object that will be converted to JSON.

### On client side

```ruby
Rack::Remote.add :srv1, url: 'http://serv.domain.tld/proxyed/path'
Rack::Remote.invoke :srv1, :factory_bot, factory: 'user'
Rack::Remote.invoke 'http://serv.domain.tld/proxyed/path', :factory_bot, factory: 'user'
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
4. Add specs
5. Add features
6. Commit your changes (`git commit -am 'Add some feature'`)
7. Push to the branch (`git push origin my-new-feature`)
8. Create new Pull Request
