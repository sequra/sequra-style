# sequra-style

SeQura code style guides and shared configuration.
Inspired by Percy Blog [post](https://blog.percy.io/share-rubocop-rules-across-all-of-your-repos-f3281fbd71f8)

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
