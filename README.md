# sequra-style

SeQura code style guide and shared configuration.

## Installation

Add this line to your application's Gemfile (the gem automatically released to [rubybems.org](https://rubygems.org/gems/sequra-style)):

```ruby
gem "sequra-style", require: false
```

And then execute:

```shell
$ bundle install
```

## Usage

Use the following directives in a `.rubocop.yml` file:

```yaml
inherit_gem:
  sequra-style:
    - default.yml

# Add any other particular settings for cops that are particular to your project here
```