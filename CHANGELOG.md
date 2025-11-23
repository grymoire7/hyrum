# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

- Renamed `OpenaiGenerator` to `AiGenerator` for implementation-agnostic naming
- Simplified generator implementation using ruby_llm's unified API
- Test suite now uses RubyLLM-level mocking instead of VCR HTTP cassettes
- **Code Quality Improvements**:
  - Extracted fake messages data to external JSON file (improved maintainability)
  - Refactored API key environment variable mapping to use constant hash
  - Reduced FakeGenerator from 298 to 36 lines
  - Reduced AiGenerator cyclomatic complexity from 12 to 1
  - All RuboCop warnings resolved

### Removed

- VCR test cassettes (replaced with direct RubyLLM mocking)
- `OpenaiGenerator` class (replaced by `AiGenerator`)

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

## [0.1.0] - 2024-12-16

### Fixed

- Minor bug fixes and spec updates
- Option defaults added in help where appropriate

### Added

- New -n | --number option to specify number of messages to produce
- New ScriptOption specs
- New MessageGenerator specs
- New FakeGenerator specs

## [0.0.2] - 2024-12-06

### Fixed

- Minor bug fixes
- Option defaults

### Added

- New OpenAI generator specs

## [0.0.1] - 2024-12-01

### Added

- This CHANGELOG file
- Initial version of the project