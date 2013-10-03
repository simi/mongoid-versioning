# Versioned documents for Mongoid4[![Build Status](https://travis-ci.org/simi/mongoid-versioning.png?branch=master)](https://travis-ci.org/simi/mongoid-versioning)

Mongoid supports simple versioning through inclusion of the Mongoid::Versioning module. Including this module will create a versions embedded relation on the document that it will append to on each save. It will also update the version number on the document, which is an integer.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'mongoid-versioning', github: 'simi/mongoid-versioning'
```

And then execute:

    $ bundle

## Usage

```ruby
class Person
  include Mongoid::Document
  include Mongoid::Versioning
end
```

You can also set a max_versions setting, and Mongoid will only keep the max most recent versions.

```ruby
class Person
  include Mongoid::Document
  include Mongoid::Versioning

  # keep at most 5 versions of a record
  max_versions 5
end
```

You may skip versioning at any point in time by wrapping the persistence call in a versionless block.

```ruby
person.versionless do |doc|
  doc.update_attributes(name: "Theodore")
end
```

## Authors

* extracted from [Mongoid](github.com/mongoid/mongoid) by [@simi](https://github.com/simi)
* [errors fixed](https://github.com/simi/mongoid-versioning/pull/1) by awesome [@gautamrege](https://github.com/gautamrege)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
