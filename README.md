# Cucumber-CTRF

Cucumber formatter to output test results in CTRF (https://www.ctrf.io/) JSON format.

## Usage

Add to Gemfile:

```ruby
cucumber-ctrf
```

Add formatter to either a Cucumber profile or CLI:

```
cucumber --format Ctrf::Formatter --out <path>.ctrf.json
```