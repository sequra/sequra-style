# sequra-style

SeQura code style guides and shared configuration.
Inspired by Percy Blog [post](https://blog.percy.io/share-rubocop-rules-across-all-of-your-repos-f3281fbd71f8)

## Installation

Add this line to your application's Gemfile:

```ruby
gem "sequra-style"
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sequra-style

## Usage

Use the following directives in a `.rubocop.yml` file:

```yaml
inherit_gem:
  sequra-style:
    - default.yml
```
