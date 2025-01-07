# Cucumber-CTRF

Cucumber formatter to output test results in CTRF (https://www.ctrf.io/) JSON format.

## Usage

Add to Gemfile:

```ruby
gem "cucumber-ctrf"
```

Add formatter to either a Cucumber profile or CLI:

```
cucumber --format Ctrf::CucumberFormatter --out <path>.ctrf.json
```
