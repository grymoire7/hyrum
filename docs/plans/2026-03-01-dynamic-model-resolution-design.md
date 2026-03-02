# Dynamic Model Resolution Design

**Date:** 2026-03-01
**Status:** Approved

## Problem

Hardcoded model names in `AI_MODEL_DEFAULTS` (e.g., `"claude-haiku-20250514"`) go stale when
providers deprecate model versions. The project needs a way to specify a provider/family tier and
resolve the actual model ID dynamically from RubyLLM's registry.

## Approach: Standalone `ModelResolver` module (Approach B)

A new `Hyrum::ModelResolver` module handles all dynamic model lookups. It is a pure function over
RubyLLM's model registry with no knowledge of Hyrum's option structs or CLI. `ScriptOptions` wires
it in during `set_dynamic_defaults`.

## Scope

Dynamic resolution applies to major cloud API providers with good RubyLLM registry coverage:
**openai, anthropic, gemini, mistral, deepseek**.

Providers where users typically supply their own model names keep literal hardcoded IDs:
**ollama, openrouter, vertexai, bedrock, gpustack, fake**.

## `ModelResolver` Module

Located at `lib/hyrum/model_resolver.rb`.

```ruby
module Hyrum
  module ModelResolver
    class ModelNotFoundError < StandardError; end

    def self.resolve(provider:, family:, strategy: :cheapest)
      models = RubyLLM.models.by_provider(provider).by_family(family)
      raise ModelNotFoundError, "No models found for #{provider}/#{family}" if models.empty?

      case strategy
      when :cheapest  then models.min_by { |m| m.input_price_per_million_tokens }
      when :newest    then models.max_by { |m| m.created_at }
      when :stable    then stable(models)
      end.id.to_sym
    end

    def self.stable(models)
      sorted = models.sort_by { |m| m.created_at }
      sorted[-2] || sorted.last
    end
    private_class_method :stable
  end
end
```

### Selection strategies

| Strategy  | Behavior                                                              |
|-----------|-----------------------------------------------------------------------|
| `:cheapest` | `min_by` input price per million tokens. Default for Hyrum.         |
| `:newest`   | `max_by` created_at. Best capability, may carry a launch premium.   |
| `:stable`   | Second-newest by created_at; falls back to newest if only one model.|

### Error handling

`ModelNotFoundError` is raised when no models match the provider+family combination. It propagates
up and is caught by the same configuration error path used for missing API keys. No fallback to a
hardcoded string — a stale hardcoded model is worse than an explicit error.

### Return value

Returns a Symbol (consistent with how model names are used throughout Hyrum). Example:
`:"claude-3-haiku-20240307"`.

## Constants in `message_generator.rb`

`AI_MODEL_DEFAULTS` is replaced by two constants:

```ruby
AI_MODEL_FAMILIES = {
  openai:    "gpt-4o-mini",
  anthropic: "claude-haiku",
  gemini:    "gemini-flash",
  mistral:   "mistral-small",
  deepseek:  "deepseek-chat"
}.freeze

AI_MODEL_LITERALS = {
  ollama:     :llama3,
  openrouter: :"openai/gpt-4o-mini",
  vertexai:   :"gemini-2.0-flash-exp",
  bedrock:    :"anthropic.claude-3-haiku-20240307-v1:0",
  gpustack:   :llama3,
  fake:       :fake
}.freeze
```

## Wiring in `ScriptOptions`

`set_dynamic_defaults` checks `AI_MODEL_FAMILIES` first and calls `ModelResolver.resolve`; if the
provider is not in that map, it falls through to `AI_MODEL_LITERALS`.

A new `--model-strategy` CLI flag accepts `cheapest` (default), `newest`, or `stable`, stored as
`options[:model_strategy]` as a Symbol.

## Testing

- `spec/hyrum/model_resolver_spec.rb`: unit tests with mocked RubyLLM registry covering each
  strategy, empty results raising `ModelNotFoundError`, and the `:stable` single-model edge case.
- `spec/hyrum/script_options_spec.rb`: new cases for dynamic resolution (mocked resolver), literal
  fallthrough, and the `--model-strategy` flag.
- `spec/hyrum/generators/message_generator_spec.rb`: update constant references from
  `AI_MODEL_DEFAULTS` to the new split constants.
- Smoke test: verify each family string in `AI_MODEL_FAMILIES` resolves against the real RubyLLM
  registry so taxonomy changes surface immediately.

## Files Changed

| File | Change |
|------|--------|
| `lib/hyrum/model_resolver.rb` | New file |
| `lib/hyrum/generators/message_generator.rb` | Replace `AI_MODEL_DEFAULTS` with `AI_MODEL_FAMILIES` + `AI_MODEL_LITERALS` |
| `lib/hyrum/script_options.rb` | Update `set_dynamic_defaults`, add `--model-strategy` flag |
| `lib/hyrum.rb` | Add `model_strategy` attribute to option structs |
| `spec/hyrum/model_resolver_spec.rb` | New file |
| `spec/hyrum/generators/message_generator_spec.rb` | Update constant references |
| `spec/hyrum/script_options_spec.rb` | New cases for strategy flag and dynamic resolution |
