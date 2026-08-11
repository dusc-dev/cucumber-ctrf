# frozen_string_literal: true

require 'cucumber/cli/options'
require 'json'

module Ctrf
  describe CucumberFormatter do
    extend Cucumber::Formatter::SpecHelperDsl
    include Cucumber::Formatter::SpecHelper

    describe 'a report already exists' do
      it 'correctly loads the file and continues on' do
        filepath = File.join(__dir__, 'files', 'example.ctrf.json')
        @formatter = described_class.new(actual_runtime.configuration.with_options(out_stream: filepath))

        expect(@formatter.instance_variable_get(:@tests).length).to eq(1)

        @formatter.on_test_run_finished(nil)
      end
    end

    describe '#attach with no active test case' do
      # Regression: #attach used to reference undefined `encode64`,
      # `test_step_output` and `test_step_embeddings`, so any attachment crashed
      # the run. When there is no active test case (e.g. an attachment from a
      # global hook) it should discard the attachment rather than raise.
      subject(:formatter) do
        described_class.new(actual_runtime.configuration.with_options(out_stream: StringIO.new))
      end

      it 'accepts an image embedding without raising' do
        expect { formatter.attach('raw-image-bytes', 'image/png', 'shot.png') }.not_to raise_error
      end

      it 'accepts a pre-base64-encoded embedding without raising' do
        expect { formatter.attach('cmF3', 'image/png;base64', 'shot.png') }.not_to raise_error
      end

      it 'accepts a cucumber log line without raising' do
        expect { formatter.attach('a log line', 'text/x.cucumber.log+plain', nil) }.not_to raise_error
      end
    end

    context 'with example-based tests' do
      before do
        @out = StringIO.new
        @formatter = described_class.new(actual_runtime.configuration.with_options(out_stream: @out))
        run_defined_feature
      end

      describe 'with a scenario with an undefined step' do
        define_feature <<~FEATURE
          Feature: Banana party

            Scenario: Monkey eats bananas
              Given there are bananas
        FEATURE

        it 'outputs the json data' do
          expect(@out.string).to be_json.with_content(
            "Undefined step: \"there are bananas\" (Cucumber::Core::Test::Result::Undefined)\nspec.feature:4:in `there are bananas'"
          ).at_path('results.tests.0.trace')
        end
      end

      describe 'with a scenario whose step attaches an embedding and logs output' do
        define_feature <<~FEATURE
          Feature: Banana party

            Scenario: Monkey photographs bananas
              Given I photograph the bananas
        FEATURE

        define_steps do
          Given(/^I photograph the bananas$/) do
            log('found 3 bananas')
            attach('raw-image-bytes', 'image/png')
          end
        end

        it 'captures the base64-encoded embedding under the test extra payload' do
          expect(@out.string).to be_json.with_content('image/png').at_path('results.tests.0.extra.embeddings.0.mime_type')
          expect(@out.string).to be_json.with_content(Base64.encode64('raw-image-bytes')).at_path('results.tests.0.extra.embeddings.0.data')
        end

        it 'captures the log output under the test extra payload' do
          expect(@out.string).to be_json.with_content('found 3 bananas').at_path('results.tests.0.extra.output.0')
        end
      end

      describe 'with a scenario with a passed step' do
        define_feature <<~FEATURE
          Feature: Banana party

            Scenario: Monkey eats bananas
              Given there are bananas
        FEATURE

        define_steps do
          Given(/^there are bananas$/) {}
        end

        it 'outputs the json data' do
          expect(@out.string).to be_json.with_content('passed').at_path('results.tests.0.status')
          expect(@out.string).to be_json.with_content(1).at_path('results.summary.passed')
        end
      end

      describe 'with a scenario with a failed step' do
        define_feature <<~FEATURE
          Feature: Banana party

            Scenario: Monkey eats bananas
              Given there are bananas
        FEATURE

        define_steps do
          Given(/^there are bananas$/) { raise 'no bananas' }
        end

        it 'outputs the json data' do
          expect(@out.string).to be_json.with_content('failed').at_path('results.tests.0.status')
          expect(@out.string).to be_json.with_content(1).at_path('results.summary.failed')
        end
      end

      describe 'with a scenario with a pending step' do
        define_feature <<~FEATURE
          Feature: Banana party

            Scenario: Monkey eats bananas
              Given there are bananas
        FEATURE

        define_steps do
          Given(/^there are bananas$/) { pending }
        end

        it 'outputs the json data' do
          expect(@out.string).to be_json.with_content('pending').at_path('results.tests.0.status')
          expect(@out.string).to be_json.with_content(1).at_path('results.summary.pending')
        end
      end

      describe 'with a scenario outline with one example' do
        define_feature <<~FEATURE
          Feature: Banana party

            Scenario Outline: Monkey eats <fruit>
              Given there are <fruit>

              Examples: Fruit Table
              |  fruit  |
              | bananas |
        FEATURE

        define_steps do
          Given(/^there are bananas$/) {}
        end

        it 'outputs the json data' do
          expect(@out.string).to be_json.with_content('passed').at_path('results.tests.0.status')
          expect(@out.string).to be_json.with_content(1).at_path('results.summary.passed')
        end
      end
    end
  end
end
