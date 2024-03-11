# sequra-style

SeQura code style guide and shared configuration.

## Installation

Add this line to your application's Gemfile (we need to point to GitHub since it's not published):

```ruby
gem "sequra-style", git: "https://github.com/sequra/sequra-style", require: false
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
```
