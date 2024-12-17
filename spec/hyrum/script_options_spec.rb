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
            it 'raises a Hyrum::ScriptOptionsError' do
                args = ['-s', 'fake']
                script_options = Hyrum::ScriptOptions.new(args)

                expect { script_options.parse }.to raise_error(Hyrum::ScriptOptionsError, /Missing argument for option:/)
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
    end
end