# Migration from ruby-openai to ruby_llm

**Date:** 2025-11-22
**Status:** Design Approved
**Version:** 1.0

## Overview

This document outlines the design for migrating hyrum from the `ruby-openai` gem to `ruby_llm`. The migration will expand provider support from just OpenAI and Ollama to all providers supported by ruby_llm (10+ providers including Anthropic, Gemini, Mistral, etc.) while simplifying the codebase.

## Motivation

The current implementation uses `ruby-openai` which provides limited LLM support (primarily OpenAI with Ollama compatibility mode). By switching to `ruby_llm`, we gain:

1. **Broader Provider Support**: Access to 10+ AI providers through a unified API
2. **Simplified Code**: ruby_llm handles provider-specific logic, reducing our maintenance burden
3. **Better Features**: Structured output via JSON schemas, automatic response parsing, improved error handling
4. **Future-Proof**: ruby_llm is actively maintained and adds new providers regularly

## Architecture

### Current System Flow

```
CLI args → ScriptOptions → CLIOptions
                          ↓
         Generator (OpenaiGenerator/FakeGenerator)
                          ↓
                    messages (JSON)
                          ↓
                      Formatter
                          ↓
                       Output
```

### Proposed Changes

**Core Changes:**
1. Replace `OpenaiGenerator` with `AIGenerator` (implementation-agnostic name)
2. Keep `FakeGenerator` unchanged for testing without API access
3. Update `MessageGenerator.create()` factory to route to appropriate generator
4. Expand supported providers from 2 to 10+

**Why "AIGenerator" not "RubyLLMGenerator":**
We want an abstraction named for what it does (AI generation), not the underlying implementation. This maintains flexibility if we switch libraries in the future.

### Updated Constants

```ruby
module Hyrum::Generators
  # Expanded provider support
  AI_SERVICES = %i[
    openai anthropic gemini ollama mistral deepseek
    perplexity openrouter vertexai bedrock gpustack fake
  ].freeze

  # Provider-specific default models
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

  # Generator class mapping
  GENERATOR_CLASSES = {
    fake: FakeGenerator
    # All other providers default to AIGenerator
  }.freeze
end
```

### MessageGenerator Factory

```ruby
class MessageGenerator
  def self.create(options)
    service = options[:ai_service].to_sym

    # Use FakeGenerator for fake service, AIGenerator for everything else
    generator_class = GENERATOR_CLASSES.fetch(service, AIGenerator)
    generator_class.new(options)
  end
end
```

## AIGenerator Implementation

### Class Design

```ruby
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
      rescue RubyLLM::ConfigurationError => e
        handle_configuration_error(e)
      rescue RubyLLM::APIError => e
        handle_api_error(e)
      rescue RubyLLM::Error => e
        handle_general_error(e)
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
    end
  end
end
```

### Key Design Decisions

1. **Structured Output**: Using `with_schema()` ensures we always get valid JSON in the exact format needed
2. **Lazy Initialization**: Chat instance created once and cached (though currently only used once per run)
3. **Error Handling**: Specific error types with helpful user messages and exit codes
4. **Provider Agnostic**: No provider-specific logic in AIGenerator - ruby_llm handles differences

## Dependencies

### Gemfile Changes

```ruby
# Remove:
gem 'ruby-openai', '~> 7.3'

# Add:
gem 'ruby_llm', '~> 1.9'

# Keep:
gem 'zeitwerk', '~> 2.7'
gem 'dry-struct', '~> 1.8'
gem 'dry-validation', '~> 1.11'
```

### Gemspec Changes

```ruby
# Remove:
gem.add_dependency 'ruby-openai', '~> 7.3'

# Add:
gem.add_dependency 'ruby_llm', '~> 1.9'

# Keep:
gem.add_dependency 'zeitwerk', '~> 2.7'
```

## Configuration Migration

### Breaking Changes

Since hyrum is pre-1.0 with few users, we're making clean breaks without migration helpers.

**Environment Variable Changes:**

| Old (ruby-openai) | New (ruby_llm) | Notes |
|-------------------|----------------|-------|
| `OPENAI_ACCESS_TOKEN` | `OPENAI_API_KEY` | Different variable name |
| `OLLAMA_URL` | `OLLAMA_API_BASE` | Must include `/v1` suffix |
| N/A | `ANTHROPIC_API_KEY` | New provider |
| N/A | `GEMINI_API_KEY` | New provider |
| N/A | `MISTRAL_API_KEY` | New provider |
| ... | ... | See ruby_llm docs for full list |

**Configuration Examples:**

```bash
# OpenAI
export OPENAI_API_KEY=sk-...

# Anthropic
export ANTHROPIC_API_KEY=sk-ant-...

# Gemini
export GEMINI_API_KEY=...

# Ollama (optional - defaults to localhost:11434/v1)
export OLLAMA_API_BASE=http://localhost:11434/v1

# AWS Bedrock
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_REGION=us-east-1

# Google Vertex AI
export GOOGLE_CLOUD_PROJECT=my-project
export GOOGLE_CLOUD_LOCATION=us-central1
```

### No Migration Helper

We considered adding a migration helper to detect old environment variables and warn users, but decided against it because:

1. Hyrum is pre-1.0 (current version < 1.0)
2. Very few real users at this point
3. Adds complexity for minimal benefit
4. Clean break is clearer for future users

Instead, we'll document breaking changes clearly in CHANGELOG.md and README.md.

## Testing Strategy

### Mock at RubyLLM Level

**Decision:** Mock `RubyLLM` directly instead of HTTP level (VCR).

**Rationale:**
- Simpler: One mock setup vs cassettes for 10+ providers
- Faster: No HTTP parsing overhead
- More maintainable: Tests don't break when ruby_llm changes request format
- Focused: Tests our code, not ruby_llm's HTTP implementation

### Test Structure

```ruby
# spec/support/ruby_llm_mocks.rb
module RubyLLMMocks
  def mock_ruby_llm_chat(content:)
    mock_response = instance_double(
      RubyLLM::Message,
      content: content,
      inspect: "RubyLLM::Message"
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

RSpec.configure do |config|
  config.include RubyLLMMocks
end
```

### Example Test

```ruby
# spec/hyrum/generators/ai_generator_spec.rb
RSpec.describe Hyrum::Generators::AIGenerator do
  let(:options) do
    {
      message: "Server refuses to brew coffee",
      key: :e418,
      number: 3,
      ai_service: :openai,
      ai_model: :'gpt-4o-mini',
      verbose: false
    }
  end

  describe '#generate' do
    it 'generates messages via ruby_llm' do
      expected = { "e418" => ["Message 1", "Message 2", "Message 3"] }
      mock_ruby_llm_chat(content: expected)

      generator = described_class.new(options)
      result = generator.generate

      expect(result).to eq(expected)
    end

    it 'handles configuration errors' do
      allow(RubyLLM).to receive(:chat)
        .and_raise(RubyLLM::ConfigurationError.new("Missing API key"))

      generator = described_class.new(options)

      expect { generator.generate }
        .to output(/Configuration Error/).to_stdout
        .and raise_error(SystemExit)
    end

    it 'handles API errors' do
      allow(RubyLLM).to receive(:chat)
        .and_raise(RubyLLM::APIError.new("Rate limit exceeded"))

      generator = described_class.new(options)

      expect { generator.generate }
        .to output(/API Error/).to_stdout
        .and raise_error(SystemExit)
    end
  end
end
```

### Test Coverage

1. **AIGenerator specs**: Test message generation, error handling, schema building
2. **FakeGenerator specs**: Keep unchanged (no external dependencies)
3. **MessageGenerator factory specs**: Test routing to correct generator class
4. **Integration tests**: End-to-end with `fake` provider
5. **Remove**: VCR cassettes for OpenAI/Ollama API calls

### VCR/WebMock Dependencies

**Decision:** Remove VCR and WebMock from the project since we're not doing HTTP-level mocking anymore.

```ruby
# Remove from Gemfile (test/development group):
# gem 'vcr', '~> 6.0'
# gem 'webmock', '~> 3.0'
```

## Error Handling

### Error Categories

1. **Configuration Errors** (`RubyLLM::ConfigurationError`)
   - Missing API keys
   - Invalid provider configuration
   - **Action**: Show helpful message with correct env var name, exit code 1

2. **API Errors** (`RubyLLM::APIError`)
   - Invalid model name
   - Rate limiting
   - Authentication failures
   - **Action**: Show error and suggest checking model validity, exit code 1

3. **General Errors** (`RubyLLM::Error`)
   - Network timeouts
   - Unexpected failures
   - **Action**: Show error message, exit code 1

### Provider-Specific Edge Cases

**Ollama not running:**
```
API Error: Connection refused - connect(2) for "localhost" port 11434
Please ensure Ollama is running: ollama serve
```

**Invalid model for provider:**
```
API Error: Model 'gpt-4' not found
Please check that 'gpt-4' is valid for anthropic.
```

**Structured output unsupported:**
Some older models don't support JSON schemas. Ruby_llm will raise an error.
- **Decision**: Let it fail with clear error message (don't fall back to unstructured)
- **Rationale**: Simpler, clearer expectations

## Documentation Updates

### README.md

1. **Configuration Section**
   - Update environment variable names
   - Add examples for all major providers (OpenAI, Anthropic, Gemini, Ollama)
   - Add troubleshooting section

2. **Supported Providers**
   - List all 10+ providers
   - Link to ruby_llm docs for provider-specific setup

3. **Example Usage**
   - Show examples with different providers
   - Demonstrate provider flexibility

### CHANGELOG.md

Add breaking changes section:

```markdown
## [Unreleased]

### Breaking Changes

- Switched from `ruby-openai` to `ruby_llm` gem
- Environment variable changes:
  - `OPENAI_ACCESS_TOKEN` → `OPENAI_API_KEY`
  - `OLLAMA_URL` → `OLLAMA_API_BASE` (must include `/v1` suffix)
- Removed OpenAI organization ID support (can be added if needed)

### Added

- Support for 10+ AI providers: Anthropic, Gemini, Mistral, DeepSeek,
  Perplexity, OpenRouter, VertexAI, Bedrock, GPUStack
- Improved error messages with provider-specific guidance
- Structured JSON output via schemas for more reliable parsing

### Changed

- Renamed `OpenaiGenerator` to `AIGenerator`
- Simplified generator implementation using ruby_llm's unified API
```

## Implementation Plan

See separate implementation plan document for detailed step-by-step tasks.

## Future Enhancements

**Not in scope for initial migration, but possible future work:**

1. **Provider-Specific Features**
   - Anthropic prompt caching for cost reduction
   - OpenAI organization/project headers
   - Custom temperature/creativity controls

2. **Advanced Configuration**
   - Config file support (`.hyrumrc`)
   - Per-provider model overrides
   - Custom prompt templates

3. **Additional Capabilities**
   - Vision models for analyzing images/diagrams
   - Multi-turn conversations for iterative refinement
   - Batch processing of multiple messages

## Success Criteria

Migration is successful when:

1. ✅ All existing functionality works with OpenAI and Ollama
2. ✅ New providers (Anthropic, Gemini, etc.) work correctly
3. ✅ Tests pass with RubyLLM-level mocking
4. ✅ Documentation updated with new configuration
5. ✅ Error messages are clear and helpful
6. ✅ No regression in output quality or format

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Ruby_llm API changes | High | Pin to specific version, test thoroughly |
| Provider inconsistencies | Medium | Extensive testing across providers |
| Structured output failures | Medium | Clear error messages, document limitations |
| Breaking existing users | Low | Few users, clear migration docs |

## Appendix: File Changes Summary

**New Files:**
- `lib/hyrum/generators/ai_generator.rb`
- `spec/hyrum/generators/ai_generator_spec.rb`
- `spec/support/ruby_llm_mocks.rb`
- `docs/plans/2025-11-22-ruby-llm-migration-design.md` (this file)

**Modified Files:**
- `lib/hyrum/generators/message_generator.rb` (update constants and factory)
- `lib/hyrum.rb` (remove ruby-openai require, add ruby_llm)
- `Gemfile` (dependency swap)
- `hyrum.gemspec` (dependency swap)
- `README.md` (configuration updates, provider list)
- `CHANGELOG.md` (breaking changes)
- `spec/spec_helper.rb` (remove VCR config, add mock helpers)

**Deleted Files:**
- `lib/hyrum/generators/openai_generator.rb`
- `spec/hyrum/generators/openai_generator_spec.rb`
- `spec/fixtures/vcr_cassettes/*` (all VCR cassettes)

**Unchanged Files:**
- `lib/hyrum/generators/fake_generator.rb`
- `spec/hyrum/generators/fake_generator_spec.rb`
- All formatter code
- All script options code
