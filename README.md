# sw_fac 0.3.0

This is a ruby library that helps to interact with the Smarted Web API and the mexican billing system (SAT).


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sw_fac'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sw_fac

## Usage

Initialize a new object with your config arguments

```ruby
# Required arguments
production_token = (String) # your production token
development_token = (String) # your dev token
rfc = (String) # your company rfc
razon_social = (String) # your company name
regimen = (String) # example 612
path_to_key = (String) # the path where the 'example.key' is
key_passphrase = (String) # password for the .key file
path_to_cer = (String) # the path where the 'example.cer' is

# Optional arguments
production = (Boolean) # environment, optional, default is -false-

# The object
obj = SwFac::Facturacion.new(production_token, development_token, rfc, razon_social, regimen, path_to_key, key_passphrase, path_to_cer, production) 
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/angelpadilla/sw_facturacion.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Support on Beerpay
Hey dude! Help me out for a couple of :beers:!

[![Beerpay](https://beerpay.io/angelpadilla/sw_facturacion/badge.svg?style=beer-square)](https://beerpay.io/angelpadilla/sw_facturacion)  [![Beerpay](https://beerpay.io/angelpadilla/sw_facturacion/make-wish.svg?style=flat-square)](https://beerpay.io/angelpadilla/sw_facturacion?focus=wish)