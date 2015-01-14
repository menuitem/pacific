# Pacific

The pacific gem will deploy your Rails project to a clean Linux based infrastructure.

## Installation
#
* Manually build:

	Clone repository:
```cli	
	$ git clone https://github.com/menuitem/pacific.git
    $ bundle
    $ rake install
```
* With bundler:

	Add gem to Gemfile:	
```ruby	
	gem 'pacific', git: 'https://github.com/menuitem/pacific.git'
```    
And run bundler:
```cli	
	$ bundle
```

* With rubygems:

Add gem sources:
```cli
   $ gem sources -r https://rubygems.org/ && gem sources -r https://rubygems.org && gem sources -a https://pacific-one.herokuapp.com/ && gem sources -a https://rubygems.org/
```
Install gem:
```cli
	$ gem install pacific
```
And you are ready to go:

```cli
	$ pacific
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/pacific/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request