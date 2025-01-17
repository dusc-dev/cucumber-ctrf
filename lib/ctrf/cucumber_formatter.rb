require 'json'
require 'base64'
require 'cucumber/formatter/backtrace_filter'
require 'cucumber/formatter/io'
require 'cucumber/formatter/ast_lookup'

module Ctrf
  class CucumberFormatter
    include Cucumber::Formatter::Io

    def initialize(config)
      # The Cucumber Formatter can get re-run many times (e.g. Knapsack)
      # So, we need to make sure we load any existing file into the test object array, if one is provided.
      if !io?(config.out_stream) && File.exist?(config.out_stream)
        data = JSON.load_file(config.out_stream)
        tests = deep_symbolize_keys(
          data.dig('results', 'tests').to_h do |test|
            [test.dig('extra', 'hash'), test]
          end
        )
        run_start = data.dig('results', 'summary', 'start')
      end

      @io = ensure_io(config.out_stream, config.error_stream)
      @ast_lookup = Cucumber::Formatter::AstLookup.new(config)

      @tests = tests || {}
      begin
        @bc = Rails::ActiveSupport::BacktraceCleaner.new
      rescue StandardError
        @bc = nil
      end

      # Use the existing run_start if there is one
      @run_start = run_start || Time.now.to_i
      config.on_event :test_case_started, &method(:on_test_case_started)
      config.on_event :test_case_finished, &method(:on_test_case_finished)
      config.on_event :test_step_started, &method(:on_test_step_started)
      config.on_event :test_step_finished, &method(:on_test_step_finished)
      config.on_event :test_run_finished, &method(:on_test_run_finished)
    end

    def on_test_case_started(event)
      # Set up the object for use if it doesn't exist already
      # It might, if retries
      return if @tests.key?(event.test_case.hash)

      @tests[event.test_case.hash] = {
        name: event.test_case.name,
        suite: event.test_case.location.file,
        filePath: event.test_case.location.to_s,
        extra: {
          hash: event.test_case.hash
        }
      }
    end

    def on_test_step_started(event)
      # Don't care about steps rn
    end

    def on_test_step_finished(event)
      # Don't care about steps rn
    end

    def on_test_case_finished(event)
      test = @tests[event.test_case.hash]
      test[:duration] = event.result.duration.nanoseconds / 1_000_000

      # Pull existing status, if any
      existing_status = test[:status]
      test[:status] = sym_to_status(event.result.to_sym)
      test[:rawStatus] = event.result.to_sym

      # If this is a retry, we failed last time and passed this time, it's flaky
      test[:flaky] = !existing_status.nil? && existing_status = 'failed' && test[:status] == 'passed'
      unless existing_status.nil?
        test[:retries] = 0 unless test.key?(:retries)
        test[:retries] += 1
      end

      # Attach error information, if any
      test[:message] = event.result.to_message.message
      exception = get_backtrace_object(event.result) unless event.result.passed?

      # If this wasn't the first run, move the trace to extra
      if test.key?(:trace)
        test[:extra][:previous_traces] = [] unless test[:extra].key?(:previous_traces)
        test[:extra][:previous_traces].push(test[:trace])
        test.delete(:trace)
      end
      test[:trace] = format_exception(exception) if exception
    end

    def on_test_run_finished(_event)
      # Build the final result object
      result = {
        results: {
          tool: {
            name: 'Cucumber-Ruby'
          },
          summary: {
            tests: @tests.count,
            passed: @tests.values.select { |test| test[:status] == 'passed' }.count,
            failed: @tests.values.select { |test| test[:status] == 'failed' }.count,
            pending: @tests.values.select { |test| test[:status] == 'pending' }.count,
            skipped: @tests.values.select { |test| test[:status] == 'skipped' }.count,
            other: @tests.values.select { |test| test[:status] == 'other' }.count,
            start: @run_start,
            stop: Time.now.to_i
          },
          tests: @tests.values
        }
      }

      @io.write(JSON.pretty_generate(result))
    end

    def attach(src, mime_type, _filename)
      if mime_type == 'text/x.cucumber.log+plain'
        test_step_output << src
        return
      end
      if mime_type =~ /;base64$/
        mime_type = mime_type[0..-8]
        data = src
      else
        data = encode64(src)
      end
      test_step_embeddings << { mime_type: mime_type, data: data }
    end

    def get_backtrace_object(result)
      if result.failed?
        result.exception
      elsif result.backtrace
        result
      end
    end

    def format_exception(exception)
      backtrace = @bc.nil? ? exception.backtrace : @bc.clean(exception.backtrace)
      (["#{exception.message} (#{exception.class})"] + backtrace[..10]).join("\n")
    end

    def sym_to_status(sym)
      case sym
      when :failed
        'failed'
      when :passed
        'passed'
      when :skipped
        'skipped'
      when :pending
        'pending'
      else
        'other'
      end
    end

    def deep_symbolize_keys(obj)
      deep_transform_keys(obj) do |key|
        key.to_sym
      rescue StandardError
        key
      end
    end

    def deep_transform_keys(obj, &block)
      _deep_transform_keys_in_object(obj, &block)
    end

    def _deep_transform_keys_in_object(object, &block)
      case object
      when Hash
        object.each_with_object({}) do |(key, value), result|
          result[yield(key)] = _deep_transform_keys_in_object(value, &block)
        end
      when Array
        object.map { |e| _deep_transform_keys_in_object(e, &block) }
      else
        object
      end
    end
  end
end
