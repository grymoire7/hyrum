# ruby_llm Migration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate hyrum from ruby-openai to ruby_llm, expanding AI provider support from 2 to 10+ providers while simplifying the codebase.

**Architecture:** Replace OpenaiGenerator with AIGenerator that uses ruby_llm's unified API. Keep FakeGenerator unchanged. Update MessageGenerator factory to route all real AI providers to AIGenerator. Use RubyLLM-level mocking instead of VCR for tests.

**Tech Stack:** Ruby 3.2+, ruby_llm gem, RSpec, dry-validation, dry-struct

---

## Task 1: Update Dependencies

**Files:**
- Modify: `Gemfile`
- Modify: `hyrum.gemspec`

**Step 1: Update Gemfile**

Replace ruby-openai with ruby_llm:

```ruby
# frozen_string_literal: true

source 'https://rubygems.org'

# Generative AI toolset for Ruby
# gem "gen-ai" # , "~> 0.4.3"
gem 'ruby_llm', '~> 1.9'
gem 'zeitwerk', '~> 2.7'
gem 'dry-struct', '~> 1.8'
gem 'dry-validation', '~> 1.11'

group :development, :test do
  # Static analysis for code quality [https://rubocop.org/]
  gem 'rubocop', require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem 'brakeman', require: false

  # Rspect testing framework [https://rspec.info/]
  gem 'rspec', '~> 3.0', require: false

  # Rake is a Make-like program implemented in Ruby
  gem 'rake', '~> 13.0'

  # Pry is a powerful alternative to the standard IRB shell for Ruby
  gem 'pry'
end
```

**Step 2: Update gemspec**

In `hyrum.gemspec`, replace ruby-openai dependency:

```ruby
# frozen_string_literal: true

# hyrum.gemspec

require_relative 'lib/hyrum/version'

Gem::Specification.new do |gem|
  gem.name          = 'hyrum'
  gem.version       = Hyrum::VERSION
  gem.summary       = 'A simple Ruby gem'
  gem.authors       = ['Tracy Atteberry']
  gem.email         = ['tracy@tracyatteberry.com']
  gem.description   = "A multi-language code generator to cope with Hyrum's law"
  gem.homepage      = 'https://github.com/grymoire7/hyrum'
  gem.licenses      = ['MIT']
  gem.required_ruby_version = '>= 3.2.0'

  gem.metadata['rubygems_mfa_required'] = 'true'
  # gem.metadata['homepage_uri'] = gem.homepage
  # gem.metadata['source_code_uri'] = gem.homepage
  gem.metadata['changelog_uri'] = "#{gem.homepage}/blob/main/CHANGELOG.md"

  gem.extra_rdoc_files = Dir['README.md', 'CHANGELOG.md', 'LICENSE.txt']
  gem.rdoc_options += [
    '--title', 'Hyrum - Hyrum\'s Law Code Generator',
    '--main', 'README.md',
    '--line-numbers',
    '--inline-source',
    '--quiet'
  ]

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  # gem.files = Dir.chdir(__dir__) do
  #   `git ls-files -z`.split("\x0").reject do |f|
  #     (File.expand_path(f) == __FILE__) ||
  #       f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor Gemfile])
  #   end
  # end
  gem.files = Dir.glob('lib/**/*') + Dir.glob('bin/**/*')

  gem.executables << 'hyrum'
  gem.require_paths = ['lib']

  # gem.add_dependency 'gen-ai', '~> 0.4'
  gem.add_dependency 'ruby_llm', '~> 1.9'
  gem.add_dependency 'zeitwerk', '~> 2.7'
end
```

**Step 3: Install new dependencies**

Run: `bundle install`

Expected: Successfully installs ruby_llm and its dependencies

**Step 4: Commit dependency changes**

```bash
git add Gemfile hyrum.gemspec Gemfile.lock
git commit -m "build: migrate from ruby-openai to ruby_llm

Replace ruby-openai dependency with ruby_llm to support multiple
AI providers through a unified API.

Breaking change: Requires new environment variable names
(OPENAI_API_KEY instead of OPENAI_ACCESS_TOKEN)."
```

---

## Task 2: Create RubyLLM Test Mocking Infrastructure

**Files:**
- Create: `spec/support/ruby_llm_mocks.rb`
- Modify: `spec/spec_helper.rb`

**Step 1: Create mock helper module**

Create `spec/support/ruby_llm_mocks.rb`:

```ruby
# frozen_string_literal: true

module RubyLLMMocks
  def mock_ruby_llm_chat(content: nil, error: nil)
    if error
      allow(RubyLLM).to receive(:chat).and_raise(error)
    else
      mock_response = instance_double(
        RubyLLM::Message,
        content: content,
        inspect: "RubyLLM::Message(content: #{content.inspect})"
      )

      mock_chat_with_schema = instance_double(
        RubyLLM::Chat,
        ask: mock_response
      )

      mock_chat = instance_double(
        RubyLLM::Chat,
        with_schema: mock_chat_with_schema
      )

      allow(RubyLLM).to receive(:chat).and_return(mock_chat)
    end
  end
end
```

**Step 2: Update spec_helper to include mocks**

Modify `spec/spec_helper.rb` to include the new mock module:

```ruby
# frozen_string_literal: true

require 'hyrum'
require 'pry'

# Load support files
Dir[File.join(__dir__, 'support', '**', '*.rb')].each { |f| require f }

RSpec.configure do |config|
  # Include mock helpers
  config.include RubyLLMMocks

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
```

**Step 3: Verify mocks load correctly**

Run: `bundle exec rspec --format documentation --dry-run`

Expected: No errors about missing constants or files

**Step 4: Commit test infrastructure**

```bash
git add spec/support/ruby_llm_mocks.rb spec/spec_helper.rb
git commit -m "test: add RubyLLM mocking infrastructure

Create mock helpers for testing AIGenerator without making real API
calls. Provides mock_ruby_llm_chat helper that can simulate successful
responses or raise errors for testing error handling."
```

---

## Task 3: Create AIGenerator with Tests (TDD)

**Files:**
- Create: `spec/hyrum/generators/ai_generator_spec.rb`
- Create: `lib/hyrum/generators/ai_generator.rb`

**Step 1: Write failing test for basic generation**

Create `spec/hyrum/generators/ai_generator_spec.rb`:

```ruby
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Hyrum::Generators::AIGenerator do
  let(:options) do
    {
      message: 'Server refuses to brew coffee with a teapot',
      key: :e418,
      number: 3,
      ai_service: :openai,
      ai_model: :'gpt-4o-mini',
      verbose: false
    }
  end

  describe '#generate' do
    it 'generates messages via ruby_llm' do
      expected_content = {
        'e418' => [
          'Invalid Brewing Method',
          'Teapot not designed for coffee brewing',
          'Please use a suitable brewing device'
        ]
      }

      mock_ruby_llm_chat(content: expected_content)

      generator = described_class.new(options)
      result = generator.generate

      expect(result).to eq(expected_content)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/hyrum/generators/ai_generator_spec.rb`

Expected: FAIL with "uninitialized constant Hyrum::Generators::AIGenerator"

**Step 3: Create minimal AIGenerator implementation**

Create `lib/hyrum/generators/ai_generator.rb`:

```ruby
# frozen_string_literal: true

require 'ruby_llm'

module Hyrum
  module Generators
    class AIGenerator
      attr_reader :options

      def initialize(options)
        @options = options
      end

      def generate
        response = chat.ask(prompt)
        puts "AI response: #{response.inspect}" if options[:verbose]
        response.content
      end

      private

      def chat
        @chat ||= RubyLLM.chat(
          model: options[:ai_model].to_s,
          provider: options[:ai_service]
        ).with_schema(response_schema)
      end

      def prompt
        <<~PROMPT
          Please provide #{options[:number]} alternative status messages for the following message:
          "#{options[:message]}"

          The messages should be unique and informative.
        PROMPT
      end

      def response_schema
        {
          type: 'object',
          properties: {
            options[:key] => {
              type: 'array',
              items: { type: 'string' },
              minItems: options[:number],
              maxItems: options[:number]
            }
          },
          required: [options[:key].to_s],
          additionalProperties: false
        }
      end
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/hyrum/generators/ai_generator_spec.rb`

Expected: PASS (1 example, 0 failures)

**Step 5: Write failing test for verbose output**

Add to `spec/hyrum/generators/ai_generator_spec.rb` inside the `#generate` describe block:

```ruby
    it 'outputs debug info when verbose is true' do
      verbose_options = options.merge(verbose: true)
      expected_content = { 'e418' => ['Message 1'] }

      mock_ruby_llm_chat(content: expected_content)

      generator = described_class.new(verbose_options)

      expect { generator.generate }.to output(/AI response/).to_stdout
    end
```

**Step 6: Run test to verify verbose test passes**

Run: `bundle exec rspec spec/hyrum/generators/ai_generator_spec.rb`

Expected: PASS (2 examples, 0 failures) - the verbose output should already work

**Step 7: Write failing test for configuration error handling**

Add to `spec/hyrum/generators/ai_generator_spec.rb`:

```ruby
  describe 'error handling' do
    it 'handles configuration errors gracefully' do
      error = RubyLLM::ConfigurationError.new('Missing API key')
      mock_ruby_llm_chat(error: error)

      generator = described_class.new(options)

      expect { generator.generate }
        .to output(/Configuration Error.*Missing API key/m).to_stdout
        .and raise_error(SystemExit)
    end
  end
```

**Step 8: Run test to verify it fails**

Run: `bundle exec rspec spec/hyrum/generators/ai_generator_spec.rb`

Expected: FAIL - error not caught, no output shown

**Step 9: Add error handling for configuration errors**

Modify `lib/hyrum/generators/ai_generator.rb`, update the `generate` method:

```ruby
      def generate
        response = chat.ask(prompt)
        puts "AI response: #{response.inspect}" if options[:verbose]
        response.content
      rescue RubyLLM::ConfigurationError => e
        handle_configuration_error(e)
      rescue RubyLLM::APIError => e
        handle_api_error(e)
      rescue RubyLLM::Error => e
        handle_general_error(e)
      end

      private

      # ... existing private methods ...

      def handle_configuration_error(error)
        puts "Configuration Error: #{error.message}"
        puts "Please set the required API key for #{options[:ai_service]}."
        puts "Example: export #{api_key_env_var_name}=your-key-here"
        exit 1
      end

      def handle_api_error(error)
        puts "API Error: #{error.message}"
        puts "Please check that '#{options[:ai_model]}' is valid for #{options[:ai_service]}."
        exit 1
      end

      def handle_general_error(error)
        puts "Error: #{error.message}"
        exit 1
      end

      def api_key_env_var_name
        case options[:ai_service]
        when :openai then 'OPENAI_API_KEY'
        when :anthropic then 'ANTHROPIC_API_KEY'
        when :gemini then 'GEMINI_API_KEY'
        when :ollama then 'OLLAMA_API_BASE'
        when :vertexai then 'GOOGLE_CLOUD_PROJECT'
        when :bedrock then 'AWS_ACCESS_KEY_ID'
        when :deepseek then 'DEEPSEEK_API_KEY'
        when :mistral then 'MISTRAL_API_KEY'
        when :perplexity then 'PERPLEXITY_API_KEY'
        when :openrouter then 'OPENROUTER_API_KEY'
        when :gpustack then 'GPUSTACK_API_KEY'
        else "#{options[:ai_service].to_s.upcase}_API_KEY"
        end
      end
```

**Step 10: Run test to verify configuration error handling passes**

Run: `bundle exec rspec spec/hyrum/generators/ai_generator_spec.rb`

Expected: PASS (3 examples, 0 failures)

**Step 11: Write failing test for API error handling**

Add to the 'error handling' describe block in `spec/hyrum/generators/ai_generator_spec.rb`:

```ruby
    it 'handles API errors gracefully' do
      error = RubyLLM::APIError.new('Rate limit exceeded')
      mock_ruby_llm_chat(error: error)

      generator = described_class.new(options)

      expect { generator.generate }
        .to output(/API Error.*Rate limit exceeded/m).to_stdout
        .and raise_error(SystemExit)
    end
```

**Step 12: Run test to verify API error test passes**

Run: `bundle exec rspec spec/hyrum/generators/ai_generator_spec.rb`

Expected: PASS (4 examples, 0 failures) - error handling should already work

**Step 13: Write failing test for general error handling**

Add to the 'error handling' describe block:

```ruby
    it 'handles general ruby_llm errors gracefully' do
      error = RubyLLM::Error.new('Unexpected error')
      mock_ruby_llm_chat(error: error)

      generator = described_class.new(options)

      expect { generator.generate }
        .to output(/Error.*Unexpected error/m).to_stdout
        .and raise_error(SystemExit)
    end
```

**Step 14: Run test to verify general error test passes**

Run: `bundle exec rspec spec/hyrum/generators/ai_generator_spec.rb`

Expected: PASS (5 examples, 0 failures)

**Step 15: Test with different providers**

Add provider variation tests:

```ruby
  describe 'provider support' do
    it 'works with anthropic provider' do
      anthropic_options = options.merge(ai_service: :anthropic, ai_model: :'claude-sonnet-4')
      expected_content = { 'e418' => ['Message 1', 'Message 2', 'Message 3'] }

      mock_ruby_llm_chat(content: expected_content)

      generator = described_class.new(anthropic_options)
      result = generator.generate

      expect(result).to eq(expected_content)
      expect(RubyLLM).to have_received(:chat).with(model: 'claude-sonnet-4', provider: :anthropic)
    end

    it 'works with gemini provider' do
      gemini_options = options.merge(ai_service: :gemini, ai_model: :'gemini-2.0-flash-exp')
      expected_content = { 'e418' => ['Message 1', 'Message 2', 'Message 3'] }

      mock_ruby_llm_chat(content: expected_content)

      generator = described_class.new(gemini_options)
      result = generator.generate

      expect(result).to eq(expected_content)
      expect(RubyLLM).to have_received(:chat).with(model: 'gemini-2.0-flash-exp', provider: :gemini)
    end
  end
```

**Step 16: Run all AIGenerator tests**

Run: `bundle exec rspec spec/hyrum/generators/ai_generator_spec.rb`

Expected: PASS (7 examples, 0 failures)

**Step 17: Commit AIGenerator implementation**

```bash
git add lib/hyrum/generators/ai_generator.rb spec/hyrum/generators/ai_generator_spec.rb
git commit -m "feat: add AIGenerator with ruby_llm support

Implement AIGenerator that uses ruby_llm to support multiple AI
providers (OpenAI, Anthropic, Gemini, Ollama, etc.) through a
unified interface.

Features:
- Structured JSON output via schemas
- Comprehensive error handling with helpful messages
- Support for all ruby_llm providers
- Verbose mode for debugging"
```

---

## Task 4: Update MessageGenerator Factory and Constants

**Files:**
- Modify: `lib/hyrum/generators/message_generator.rb`

**Step 1: Write failing test for expanded AI services**

Modify `spec/hyrum/generators/message_generator_spec.rb`:

```ruby
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Hyrum::Generators::MessageGenerator do
  describe '.create' do
    it 'returns FakeGenerator for fake service' do
      options = { ai_service: :fake }
      generator = described_class.create(options)
      expect(generator).to be_a(Hyrum::Generators::FakeGenerator)
    end

    it 'returns AIGenerator for openai service' do
      options = { ai_service: :openai, ai_model: :'gpt-4o-mini', message: 'test', key: :e418, number: 3, verbose: false }
      generator = described_class.create(options)
      expect(generator).to be_a(Hyrum::Generators::AIGenerator)
    end

    it 'returns AIGenerator for anthropic service' do
      options = { ai_service: :anthropic, ai_model: :'claude-sonnet-4', message: 'test', key: :e418, number: 3, verbose: false }
      generator = described_class.create(options)
      expect(generator).to be_a(Hyrum::Generators::AIGenerator)
    end

    it 'returns AIGenerator for gemini service' do
      options = { ai_service: :gemini, ai_model: :'gemini-2.0-flash-exp', message: 'test', key: :e418, number: 3, verbose: false }
      generator = described_class.create(options)
      expect(generator).to be_a(Hyrum::Generators::AIGenerator)
    end

    it 'returns AIGenerator for ollama service' do
      options = { ai_service: :ollama, ai_model: :llama3, message: 'test', key: :e418, number: 3, verbose: false }
      generator = described_class.create(options)
      expect(generator).to be_a(Hyrum::Generators::AIGenerator)
    end
  end

  describe 'AI_SERVICES constant' do
    it 'includes all supported providers' do
      expect(Hyrum::Generators::AI_SERVICES).to include(
        :openai, :anthropic, :gemini, :ollama, :mistral,
        :deepseek, :perplexity, :openrouter, :vertexai,
        :bedrock, :gpustack, :fake
      )
    end
  end

  describe 'AI_MODEL_DEFAULTS constant' do
    it 'has defaults for all providers' do
      expect(Hyrum::Generators::AI_MODEL_DEFAULTS).to include(
        openai: :'gpt-4o-mini',
        anthropic: :'claude-sonnet-4',
        gemini: :'gemini-2.0-flash-exp',
        ollama: :llama3,
        fake: :fake
      )
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/hyrum/generators/message_generator_spec.rb`

Expected: FAIL - tests expect AIGenerator but OpenaiGenerator is returned

**Step 3: Update MessageGenerator with new constants and factory logic**

Modify `lib/hyrum/generators/message_generator.rb`:

```ruby
# frozen_string_literal: true

module Hyrum
  module Generators
    AI_SERVICES = %i[
      openai anthropic gemini ollama mistral deepseek
      perplexity openrouter vertexai bedrock gpustack fake
    ].freeze

    AI_MODEL_DEFAULTS = {
      openai: :'gpt-4o-mini',
      anthropic: :'claude-sonnet-4',
      gemini: :'gemini-2.0-flash-exp',
      ollama: :llama3,
      mistral: :'mistral-small-latest',
      deepseek: :'deepseek-chat',
      perplexity: :'llama-3.1-sonar-small-128k-online',
      openrouter: :'openai/gpt-4o-mini',
      vertexai: :'gemini-2.0-flash-exp',
      bedrock: :'anthropic.claude-sonnet-4-20250514-v1:0',
      gpustack: :llama3,
      fake: :fake
    }.freeze

    GENERATOR_CLASSES = {
      fake: FakeGenerator
      # All other providers default to AIGenerator
    }.freeze

    class MessageGenerator
      def self.create(options)
        service = options[:ai_service].to_sym

        # Get generator class, defaulting to AIGenerator for unlisted services
        generator_class = GENERATOR_CLASSES.fetch(service, AIGenerator)
        generator_class.new(options)
      end
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/hyrum/generators/message_generator_spec.rb`

Expected: PASS (all examples passing)

**Step 5: Commit MessageGenerator updates**

```bash
git add lib/hyrum/generators/message_generator.rb spec/hyrum/generators/message_generator_spec.rb
git commit -m "feat: update MessageGenerator for multi-provider support

Expand AI_SERVICES to include all ruby_llm providers and update
factory to route all non-fake providers to AIGenerator.

Supported providers: OpenAI, Anthropic, Gemini, Ollama, Mistral,
DeepSeek, Perplexity, OpenRouter, VertexAI, Bedrock, GPUStack, fake."
```

---

## Task 5: Remove OpenaiGenerator and Old Tests

**Files:**
- Delete: `lib/hyrum/generators/openai_generator.rb`
- Delete: `spec/hyrum/generators/openai_generator_spec.rb`

**Step 1: Verify all tests pass without OpenaiGenerator**

Run: `bundle exec rspec`

Expected: All tests pass (OpenaiGenerator no longer referenced)

**Step 2: Remove OpenaiGenerator files**

```bash
git rm lib/hyrum/generators/openai_generator.rb
git rm spec/hyrum/generators/openai_generator_spec.rb
```

**Step 3: Verify tests still pass**

Run: `bundle exec rspec`

Expected: All tests pass

**Step 4: Commit removal**

```bash
git commit -m "refactor: remove OpenaiGenerator

Remove OpenaiGenerator as it has been replaced by AIGenerator which
supports multiple providers through ruby_llm."
```

---

## Task 6: Update Main Module Require

**Files:**
- Modify: `lib/hyrum.rb`

**Step 1: Update require statement**

The `lib/hyrum.rb` file uses Zeitwerk for autoloading, so we don't need to explicitly require ruby_llm there. However, we should verify AIGenerator loads correctly.

Run: `bundle exec ruby -e "require './lib/hyrum'; puts Hyrum::Generators::AIGenerator"`

Expected: Outputs the class name without errors

**Step 2: Test end-to-end with fake generator**

Run: `./bin/hyrum -s fake -f text -k e418`

Expected: Outputs fake messages without errors

**Step 3: If the above works, no changes needed to lib/hyrum.rb**

The Zeitwerk loader will automatically load AIGenerator when needed.

---

## Task 7: Update README with New Configuration

**Files:**
- Modify: `README.md`

**Step 1: Update configuration section**

Modify the "Configuration" section in `README.md` (around line 99-124):

```markdown
## Configuration

### OpenAI (`--service openai`)
Hyrum requires an OpenAI API key to access the language models. The API key should be
set as an environment variable as shown below.

```bash
export OPENAI_API_KEY=your_openai_api_key
```

If you specify the `openai` service but no model, Hyrum will use `gpt-4o-mini`.

### Anthropic (`--service anthropic`)
To use Anthropic's Claude models, set your API key:

```bash
export ANTHROPIC_API_KEY=your_anthropic_api_key
```

Default model: `claude-sonnet-4`

### Gemini (`--service gemini`)
To use Google's Gemini models, set your API key:

```bash
export GEMINI_API_KEY=your_gemini_api_key
```

Default model: `gemini-2.0-flash-exp`

### Ollama (`--service ollama`)
If you specify the `ollama` service, Hyrum will attempt to use the Ollama API
running at `http://localhost:11434/v1`. You can set the `OLLAMA_API_BASE` environment
variable to specify a different URL.

Make sure your ollama server is running before using the `ollama` service.

```bash
ollama serve
```

Use `ollama list` to see the available models. For more information on using
ollama and downloading models, see the [ollama repository](http://ollama.com).

Default model: `llama3`

### Other Providers

Hyrum supports all providers available in [ruby_llm](https://github.com/crmne/ruby_llm),
including:
- **Mistral** (`--service mistral`) - Set `MISTRAL_API_KEY`
- **DeepSeek** (`--service deepseek`) - Set `DEEPSEEK_API_KEY`
- **Perplexity** (`--service perplexity`) - Set `PERPLEXITY_API_KEY`
- **OpenRouter** (`--service openrouter`) - Set `OPENROUTER_API_KEY`
- **Vertex AI** (`--service vertexai`) - Set `GOOGLE_CLOUD_PROJECT` and `GOOGLE_CLOUD_LOCATION`
- **AWS Bedrock** (`--service bedrock`) - Uses AWS credential chain or set `AWS_ACCESS_KEY_ID`
- **GPUStack** (`--service gpustack`) - Set `GPUSTACK_API_BASE` and `GPUSTACK_API_KEY`

See the [ruby_llm configuration docs](https://ruby-llm.com/configuration) for detailed
setup instructions for each provider.
```

**Step 2: Update usage examples**

Update the usage section to show multi-provider examples. Modify around line 28-32:

```markdown
## Example

Generate coffee brewing error messages with OpenAI:

```bash
hyrum --service openai \
      --message "The server refuses the attempt to brew coffee with a teapot" \
      --key e418 \
      --format ruby
```

Or use Anthropic's Claude:

```bash
hyrum --service anthropic \
      --message "The server refuses the attempt to brew coffee with a teapot" \
      --key e418 \
      --format ruby
```

Output:

```ruby
# frozen_string_literal: true

module Messages
  MESSAGES = {
    e418: [
      "Invalid Brewing Method",
      "Teapot not designed for coffee brewing",
      "Please use a suitable brewing device",
      "Coffee and tea are two distinct beverages with different requirements",
      "Check your equipment and try again"
    ]
  }.freeze

  def self.message(key)
    MESSAGES[key].sample
  end
end

if $PROGRAM_NAME == __FILE__
  puts Messages.message(ARGV[0].to_sym)
end
```
```

**Step 3: Update supported formats and services section**

Update line 125-127:

```markdown
## Supported formats and AI services

**Formats:** ruby, javascript, python, java, text, json

**AI Services:** openai, anthropic, gemini, ollama, mistral, deepseek, perplexity,
openrouter, vertexai, bedrock, gpustack, fake

See [Configuration](#configuration) for setup details for each service.
```

**Step 4: Commit README updates**

```bash
git add README.md
git commit -m "docs: update README for multi-provider support

Update configuration section with examples for OpenAI, Anthropic,
Gemini, Ollama, and other providers. Add usage examples showing
different providers.

Breaking change: OPENAI_ACCESS_TOKEN → OPENAI_API_KEY"
```

---

## Task 8: Update CHANGELOG

**Files:**
- Modify: `CHANGELOG.md`

**Step 1: Add unreleased section with breaking changes**

Add to the top of `CHANGELOG.md`:

```markdown
## [Unreleased]

### Breaking Changes

- **Dependency Migration**: Switched from `ruby-openai` gem to `ruby_llm` gem
- **Environment Variable Changes**:
  - `OPENAI_ACCESS_TOKEN` → `OPENAI_API_KEY` (renamed)
  - `OLLAMA_URL` → `OLLAMA_API_BASE` (renamed, must include `/v1` suffix)
- **Removed Features**:
  - OpenAI organization ID configuration (can be added back if needed)

### Added

- Support for 10+ AI providers through ruby_llm:
  - Anthropic Claude (anthropic)
  - Google Gemini (gemini)
  - Mistral AI (mistral)
  - DeepSeek (deepseek)
  - Perplexity (perplexity)
  - OpenRouter (openrouter)
  - Google Vertex AI (vertexai)
  - AWS Bedrock (bedrock)
  - GPUStack (gpustack)
- Improved error messages with provider-specific configuration guidance
- Structured JSON output via schemas for more reliable message parsing
- Better model defaults for each provider

### Changed

- Renamed `OpenaiGenerator` to `AIGenerator` for implementation-agnostic naming
- Simplified generator implementation using ruby_llm's unified API
- Test suite now uses RubyLLM-level mocking instead of VCR HTTP cassettes

### Removed

- VCR test cassettes (replaced with direct RubyLLM mocking)
- `OpenaiGenerator` class (replaced by `AIGenerator`)

### Migration Guide

1. Update environment variables:
   ```bash
   # Old
   export OPENAI_ACCESS_TOKEN=sk-...
   export OLLAMA_URL=http://localhost:11434

   # New
   export OPENAI_API_KEY=sk-...
   export OLLAMA_API_BASE=http://localhost:11434/v1
   ```

2. Add new provider API keys as needed:
   ```bash
   export ANTHROPIC_API_KEY=sk-ant-...
   export GEMINI_API_KEY=...
   ```

3. Update your Gemfile and run `bundle install`:
   ```ruby
   gem 'hyrum'  # latest version
   ```

For detailed migration instructions, see the [README](README.md#configuration).

```

**Step 2: Commit CHANGELOG**

```bash
git add CHANGELOG.md
git commit -m "docs: add migration guide to CHANGELOG

Document breaking changes and migration path from ruby-openai to
ruby_llm. Include environment variable changes and new provider
support."
```

---

## Task 9: Integration Testing

**Files:**
- None (testing existing code)

**Step 1: Run full test suite**

Run: `bundle exec rspec`

Expected: All tests pass

**Step 2: Test CLI with fake generator**

Run: `./bin/hyrum -s fake -f ruby -k e418 -n 5`

Expected: Outputs Ruby code with 5 message variations for e418

**Step 3: Test CLI with text format**

Run: `./bin/hyrum -s fake -f text -k e404`

Expected: Outputs text format with 404 error messages

**Step 4: Test CLI with JSON format**

Run: `./bin/hyrum -s fake -f json -k e500 -n 3`

Expected: Outputs valid JSON with 3 messages

**Step 5: Test verbose mode**

Run: `./bin/hyrum -s fake -f text -k e418 -v`

Expected: Shows debug output and messages

**Step 6: Test invalid service (should still work for fake)**

Run: `./bin/hyrum -s fake -f text -k e418`

Expected: Works (fake doesn't validate service)

**Step 7: Manual test with real provider (optional)**

If you have an API key configured:

Run: `./bin/hyrum -s openai -m "Resource not found" -k e404 -n 3`

Expected: Generates 3 unique 404 messages via OpenAI

**Step 8: Document successful integration test**

If all tests pass, no commit needed. Integration verified.

---

## Task 10: Final Cleanup and Verification

**Files:**
- Review all modified files

**Step 1: Run rubocop**

Run: `bundle exec rubocop`

Expected: No offenses detected (or auto-correct if needed)

If there are offenses:

Run: `bundle exec rubocop -A`

Then commit if changes were made:

```bash
git add -A
git commit -m "style: apply rubocop auto-corrections"
```

**Step 2: Run full test suite one more time**

Run: `bundle exec rspec`

Expected: All tests pass

**Step 3: Verify git status is clean**

Run: `git status`

Expected: Working tree clean (all changes committed)

**Step 4: Review commit history**

Run: `git log --oneline -10`

Expected: See logical sequence of commits following conventional commit format

**Step 5: Create summary of changes**

Run: `git diff origin/main --stat`

Expected: See summary of all files changed

Files that should be modified/added:
- `Gemfile` - dependency update
- `hyrum.gemspec` - dependency update
- `lib/hyrum/generators/ai_generator.rb` - new file
- `lib/hyrum/generators/message_generator.rb` - updated constants
- `spec/hyrum/generators/ai_generator_spec.rb` - new file
- `spec/hyrum/generators/message_generator_spec.rb` - updated tests
- `spec/support/ruby_llm_mocks.rb` - new file
- `spec/spec_helper.rb` - include mocks
- `README.md` - configuration updates
- `CHANGELOG.md` - migration guide
- `docs/plans/2025-11-22-ruby-llm-migration-design.md` - design doc
- `docs/plans/2025-11-22-ruby-llm-migration.md` - this plan

Files that should be deleted:
- `lib/hyrum/generators/openai_generator.rb`
- `spec/hyrum/generators/openai_generator_spec.rb`

---

## Success Criteria

Migration is complete when:

- ✅ All tests pass
- ✅ Fake generator still works for testing without API keys
- ✅ CLI works with multiple providers (tested with fake, optionally with real API)
- ✅ Documentation updated (README, CHANGELOG)
- ✅ Code follows style guide (rubocop clean)
- ✅ All changes committed with conventional commit messages
- ✅ Git history is clean and logical

---

## Notes

- **DRY**: Reused mock infrastructure across all generator tests
- **YAGNI**: Only implemented features needed now, not hypothetical future needs
- **TDD**: Wrote tests before implementation for AIGenerator
- **Frequent Commits**: Each major component committed separately with clear messages

## Troubleshooting

**Issue: RubyLLM constant not found**

Solution: Ensure `bundle install` was run after updating Gemfile

**Issue: Tests fail with "uninitialized constant RubyLLM::Message"**

Solution: Check that mocks in `spec/support/ruby_llm_mocks.rb` are loaded via spec_helper

**Issue: CLI doesn't recognize new providers**

Solution: Verify AI_SERVICES constant in message_generator.rb includes the provider

**Issue: Real API calls fail with configuration errors**

Solution: Check environment variables match new naming:
- `OPENAI_API_KEY` (not `OPENAI_ACCESS_TOKEN`)
- `OLLAMA_API_BASE` must include `/v1` suffix
