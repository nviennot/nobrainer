# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- Dockerfile, docker-compose and Earthfile
- Test Ruby 3 + Rails 6 on Travis CI
- Implements the ReQL `during` command
- Implements polymorphic associations

## [0.34.1] - 2021-02-18
### Fixed
- Defining attributes at class level (Rails 6.1 compatibity)
- Ruby 2.7 support

## [0.34.0] - 2019-10-15
### Added
- Rails 6 support
- Support for the nonvoting_replica_tags table option

## [0.33.0] - 2016-11-27
### Added
- Allow a run_options to be configured globally
- Support for username and password authentication

### Changed
- Use URI.decode() for user and password in the RethinkDB URL
- Also comment active_record lines in the config/initializers/*.rb on gem installation
- Removed .unscoped when fetching belongs_to associations
- update_all() operates without ordering
- has_many dependent refactoring
- Default logger should be STDERR if the rails logger is not initialized
- Locking: changes lock key type from string to text in order to support more than 255 characters keys by default, the key type needs to be Text.
- field type for rql_function to :text 

### Fixed
- Model reloading with Rails5
- Rails 5 Strong Parameters: Strong parameters are not a Hash anymore in Rails 5, but support transforming into a hash

## [0.32.0] - 2016-06-05
### Added
- Compatiblity with Rails5
- order() as an alias of order_by()
- Provide attribute_will_change!() for compatibility

### Changed
- Comments more active_record related configs during install

### Fixed
- Rails 5 deprecation: Using ActiveSupport::Reloader instead of ActionDispatch::Reloader to be ready when Rails 5 hits
- config syntax

### Removed
- JRuby and Rbx in travis-ci

## [0.31.0] - 2016-02-07
### Added
- Allow belongs_to association names to be used in upsert params
- `uniq` shorthand for the belongs_to association
- Allow self-referential belongs_to
- Prevent double loading of the same model
- Use index for where(XXX.defined => true)
- Guard against bad virtual attribute expressions
- Allow non existing attributes to be lazy fetched
- Added back update_attributes()

### Fixed
- Fix join on keys that are undefined

### Changed
- where() leverages the association translation abstraction
- Primary keys time offset should operate on fixed timezone

### Removed
- Removing locking around sync_table_config

## [0.30.0] - 2015-10-03
### Added
- Add rbx-2 to .travis.yml
- Add the virtual attribute feature
- Lock: Allow find() to get locks by key
- Locks: Allow default expire/timeout values to be passed in new()
- NoBrainer::ReentrantLock implementation
- Allow compound indexes to be declared with an implicit name
- Allow polymorphic queries with first_or_create under certain conditions

### Changed
- Prevent first_or_create() to accept block with arguments

### Fixed
- Fix rails issue with tests and profiler
- Fix where() .include modifier with type checking
- Virtual attribute option fix
- Discard documents when join() encounter a nil join key
- Locks: bug fix: allow small timeouts in lock()
- Fix reentrant lock counter on steals

[Unreleased]: https://github.com/nobrainerorm/nobrainer/compare/v0.34.1...HEAD
[0.34.1]: https://github.com/nobrainerorm/nobrainer/compare/v0.34.0...v0.34.1
[0.34.0]: https://github.com/nobrainerorm/nobrainer/compare/v0.33.0...v0.34.0
[0.33.0]: https://github.com/nobrainerorm/nobrainer/compare/v0.32.0...v0.33.0
[0.32.0]: https://github.com/nobrainerorm/nobrainer/compare/v0.31.0...v0.32.0
[0.31.0]: https://github.com/nobrainerorm/nobrainer/compare/v0.30.0...v0.31.0
[0.30.0]: https://github.com/nobrainerorm/nobrainer/compare/v0.29.0...v0.30.0
[0.29.0]: https://github.com/nobrainerorm/nobrainer/compare/0.28.0...0.29.0
[0.28.0]: https://github.com/nobrainerorm/nobrainer/compare/0.27.0...0.28.0
[0.27.0]: https://github.com/nobrainerorm/nobrainer/compare/0.26.0...0.27.0
[0.26.0]: https://github.com/nobrainerorm/nobrainer/compare/0.25.1...0.26.0
[0.25.1]: https://github.com/nobrainerorm/nobrainer/compare/0.25.0...0.25.1
[0.25.0]: https://github.com/nobrainerorm/nobrainer/compare/0.24.0...0.25.0
[0.24.0]: https://github.com/nobrainerorm/nobrainer/compare/0.23.0...0.24.0
[0.23.0]: https://github.com/nobrainerorm/nobrainer/compare/0.22.0...0.23.0
[0.22.0]: https://github.com/nobrainerorm/nobrainer/compare/0.21.0...0.22.0
[0.21.0]: https://github.com/nobrainerorm/nobrainer/compare/0.20.0...0.21.0
[0.20.0]: https://github.com/nobrainerorm/nobrainer/compare/0.19.0...0.20.0
[0.19.0]: https://github.com/nobrainerorm/nobrainer/compare/0.18.1...0.19.0
[0.18.1]: https://github.com/nobrainerorm/nobrainer/compare/0.18.0...0.18.1
[0.18.0]: https://github.com/nobrainerorm/nobrainer/compare/0.17.0...0.18.0
[0.17.0]: https://github.com/nobrainerorm/nobrainer/compare/0.16.0...0.17.0
[0.16.0]: https://github.com/nobrainerorm/nobrainer/compare/0.15.0...0.16.0
[0.15.0]: https://github.com/nobrainerorm/nobrainer/compare/0.14.0...0.15.0
[0.15.0]: https://github.com/nobrainerorm/nobrainer/compare/0.14.0...0.15.0
[0.14.0]: https://github.com/nobrainerorm/nobrainer/compare/0.13.1...0.14.0
[0.13.1]: https://github.com/nobrainerorm/nobrainer/compare/0.13.0...0.13.1
[0.13.0]: https://github.com/nobrainerorm/nobrainer/compare/0.12.0...0.13.0
[0.12.0]: https://github.com/nobrainerorm/nobrainer/compare/0.11.0...0.12.0
[0.11.0]: https://github.com/nobrainerorm/nobrainer/compare/0.10.0...0.11.0
[0.10.0]: https://github.com/nobrainerorm/nobrainer/compare/0.9.1...0.10.0
[0.9.1]: https://github.com/nobrainerorm/nobrainer/compare/0.9.0...0.9.1
[0.9.0]: https://github.com/nobrainerorm/nobrainer/compare/0.8.0...0.9.0
[0.8.0]: https://github.com/nobrainerorm/nobrainer/releases/tag/0.8.0
