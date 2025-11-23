# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Hyrum::ScriptOptions do
  describe '#parse' do
    context 'with valid options' do
      it 'parses the options correctly' do
        args = ['-m', 'Hello', '-s', 'fake', '-d', 'model1', '-k', 'status', '-f', 'text', '--verbose', '-n', '7']
        script_options = Hyrum::ScriptOptions.new(args)
        options = script_options.parse

        expect(options[:message]).to eq('Hello')
        expect(options[:ai_service]).to eq(:fake)
        expect(options[:ai_model]).to eq(:model1)
        expect(options[:key]).to eq(:status)
        expect(options[:format]).to eq(:text)
        expect(options[:verbose]).to be true
        expect(options[:number]).to eq(7)
      end
    end

    context 'with missing mandatory option' do
      it 'raises a Hyrum::ScriptOptionsError when not using fake service' do
        args = ['-s', 'openai']
        script_options = Hyrum::ScriptOptions.new(args)

        expect { script_options.parse }.to raise_error(Hyrum::ScriptOptionsError, /Missing argument for option:/)
      end

      it 'allows missing message option when using fake service' do
        args = ['-s', 'fake']
        script_options = Hyrum::ScriptOptions.new(args)

        expect { script_options.parse }.not_to raise_error
      end
    end

    context 'with invalid option' do
      it 'outputs an error message and raises SystemExit' do
        args = ['--invalid']
        script_options = Hyrum::ScriptOptions.new(args)

        expect { script_options.parse }.to raise_error(Hyrum::ScriptOptionsError, /Invalid option:/)
      end
    end

    context 'with missing argument' do
      it 'outputs an error message and raises SystemExit' do
        args = ['-m']
        script_options = Hyrum::ScriptOptions.new(args)

        expect { script_options.parse }.to raise_error(Hyrum::ScriptOptionsError, /Missing argument for option:/)
      end
    end

    context 'with invalid service argument' do
      it 'outputs an error message and raises SystemExit' do
        args = ['-s', 'invalid_service']
        script_options = Hyrum::ScriptOptions.new(args)

        expect { script_options.parse }.to raise_error(Hyrum::ScriptOptionsError, /Invalid argument for option:/)
      end
    end

    context 'with invalid number argument' do
      it 'raises a Hyrum::ScriptOptionsError' do
        args = ['-n', 'invalid_number']
        script_options = Hyrum::ScriptOptions.new(args)

        expect { script_options.parse }.to raise_error(Hyrum::ScriptOptionsError, /Invalid argument for option:/)
      end
    end

    context 'with number option for fake service' do
      it 'returns the specified number of messages' do
        args = ['-s', 'fake', '-k', '404', '-n', '3']
        script_options = Hyrum::ScriptOptions.new(args)
        options = script_options.parse

        expect(options[:number]).to eq(3)
      end
    end

    context 'with validation options' do
      it 'parses --validate flag' do
        args = %w[--validate -s fake -m test]
        options = Hyrum::ScriptOptions.new(args).parse
        expect(options[:validate]).to be true
      end

      it 'parses --min-quality with value' do
        args = %w[--validate --min-quality 80 -s fake -m test]
        options = Hyrum::ScriptOptions.new(args).parse
        expect(options[:min_quality]).to eq(80)
      end

      it 'defaults min-quality to 70' do
        args = %w[--validate -s fake -m test]
        options = Hyrum::ScriptOptions.new(args).parse
        expect(options[:min_quality]).to eq(70)
      end

      it 'parses --strict flag' do
        args = %w[--validate --strict -s fake -m test]
        options = Hyrum::ScriptOptions.new(args).parse
        expect(options[:strict]).to be true
      end

      it 'parses --show-scores flag' do
        args = %w[--validate --show-scores -s fake -m test]
        options = Hyrum::ScriptOptions.new(args).parse
        expect(options[:show_scores]).to be true
      end

      it 'defaults validate to false' do
        args = %w[-s fake -m test]
        options = Hyrum::ScriptOptions.new(args).parse
        expect(options[:validate]).to be false
      end

      it 'rejects min-quality below 0' do
        args = %w[--validate --min-quality -10 -s fake -m test]
        parsed = Hyrum::ScriptOptions.new(args).parse
        expect {
          CLIOptions.build_and_validate(parsed)
        }.to raise_error(Hyrum::ScriptOptionsError, /min_quality/)
      end

      it 'rejects min-quality above 100' do
        args = %w[--validate --min-quality 150 -s fake -m test]
        parsed = Hyrum::ScriptOptions.new(args).parse
        expect {
          CLIOptions.build_and_validate(parsed)
        }.to raise_error(Hyrum::ScriptOptionsError, /min_quality/)
      end
    end
  end
end
