# Dynamic Model Resolution Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace hardcoded model name strings with a `ModelResolver` module that dynamically picks a model by provider + family + selection strategy from RubyLLM's built-in registry.

**Architecture:** A pure `Hyrum::ModelResolver` module resolves `(provider, family, strategy)` → model ID symbol using RubyLLM's registry. `ScriptOptions` wires it in during `set_dynamic_defaults`, replacing `AI_MODEL_DEFAULTS` with two constants: `AI_MODEL_FAMILIES` (cloud APIs, resolved dynamically) and `AI_MODEL_LITERALS` (ollama/bedrock/etc., kept as-is). A new `--model-strategy` CLI flag (default `:cheapest`) controls selection.

**Tech Stack:** Ruby, RubyLLM gem (`RubyLLM.models.by_provider.by_family`), RSpec, dry-struct

---

## Key facts from inspecting the live RubyLLM registry

Real attribute names on `RubyLLM::Model::Info`:
- `.id` — model string (e.g. `"claude-3-5-haiku-20241022"`)
- `.input_price_per_million` — float cost per million input tokens
- `.created_at` — `Time` object

Confirmed family names (from `bundle exec ruby -e "require 'ruby_llm'; ..."`):
- anthropic → `"claude-haiku"`
- openai    → `"gpt-mini"` (covers gpt-4o-mini, gpt-4.1-mini, gpt-5-mini)
- gemini    → `"gemini-flash"`
- mistral   → `"mistral-small"`
- deepseek  → `"deepseek"` (covers deepseek-chat)

---

### Task 1: Create `ModelResolver` — write failing tests first

**Files:**
- Create: `spec/hyrum/model_resolver_spec.rb`
- Create: `lib/hyrum/model_resolver.rb`

**Step 1: Write the failing spec**

Create `spec/hyrum/model_resolver_spec.rb`:

```ruby
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Hyrum::ModelResolver do
  let(:cheap_model) { instance_double(RubyLLM::Model::Info, id: "cheap-model", input_price_per_million: 0.25, created_at: Time.new(2024, 1, 1)) }
  let(:mid_model)   { instance_double(RubyLLM::Model::Info, id: "mid-model",   input_price_per_million: 1.0,  created_at: Time.new(2024, 6, 1)) }
  let(:pricey_model){ instance_double(RubyLLM::Model::Info, id: "pricey-model",input_price_per_million: 3.0,  created_at: Time.new(2024, 3, 1)) }
  let(:models)      { [cheap_model, mid_model, pricey_model] }

  before do
    provider_filtered = double("provider_filtered")
    allow(RubyLLM).to receive(:models).and_return(double("registry",
      by_provider: provider_filtered))
    allow(provider_filtered).to receive(:by_family).with("claude-haiku").and_return(models)
    allow(provider_filtered).to receive(:by_family).with("unknown-family").and_return([])
  end

  describe ".resolve" do
    context "with :cheapest strategy (default)" do
      it "returns the model id with lowest input_price_per_million" do
        result = described_class.resolve(provider: :anthropic, family: "claude-haiku")
        expect(result).to eq(:"cheap-model")
      end
    end

    context "with :newest strategy" do
      it "returns the model id with the most recent created_at" do
        result = described_class.resolve(provider: :anthropic, family: "claude-haiku", strategy: :newest)
        expect(result).to eq(:"mid-model")
      end
    end

    context "with :stable strategy" do
      it "returns the second-newest model by created_at" do
        result = described_class.resolve(provider: :anthropic, family: "claude-haiku", strategy: :stable)
        expect(result).to eq(:"pricey-model")
      end
    end

    context "with :stable strategy and only one model" do
      it "falls back to the single model" do
        allow(RubyLLM.models.by_provider(:anthropic)).to receive(:by_family)
          .with("claude-haiku").and_return([cheap_model])
        result = described_class.resolve(provider: :anthropic, family: "claude-haiku", strategy: :stable)
        expect(result).to eq(:"cheap-model")
      end
    end

    context "when no models match" do
      it "raises ModelNotFoundError" do
        expect {
          described_class.resolve(provider: :anthropic, family: "unknown-family")
        }.to raise_error(Hyrum::ModelResolver::ModelNotFoundError, /anthropic.*unknown-family/)
      end
    end
  end
end
```

**Step 2: Run spec to confirm it fails**

```bash
bundle exec rspec spec/hyrum/model_resolver_spec.rb
```

Expected: red — `uninitialized constant Hyrum::ModelResolver`

**Step 3: Implement `ModelResolver`**

Create `lib/hyrum/model_resolver.rb`:

```ruby
# frozen_string_literal: true

module Hyrum
  module ModelResolver
    class ModelNotFoundError < StandardError; end

    def self.resolve(provider:, family:, strategy: :cheapest)
      models = RubyLLM.models.by_provider(provider).by_family(family)
      raise ModelNotFoundError, "No models found for #{provider}/#{family}" if models.empty?

      selected = case strategy
      when :cheapest then models.min_by(&:input_price_per_million)
      when :newest   then models.max_by(&:created_at)
      when :stable   then stable(models)
      end

      selected.id.to_sym
    end

    def self.stable(models)
      sorted = models.sort_by(&:created_at)
      sorted[-2] || sorted.last
    end
    private_class_method :stable
  end
end
```

**Step 4: Run spec to confirm it passes**

```bash
bundle exec rspec spec/hyrum/model_resolver_spec.rb
```

Expected: green

**Step 5: Commit**

```bash
git add lib/hyrum/model_resolver.rb spec/hyrum/model_resolver_spec.rb
git commit -m "feat: add ModelResolver module with cheapest/newest/stable strategies"
```

---

### Task 2: Split `AI_MODEL_DEFAULTS` into two constants

**Files:**
- Modify: `lib/hyrum/generators/message_generator.rb`
- Modify: `spec/hyrum/generators/message_generator_spec.rb`

**Step 1: Write the failing test first**

In `spec/hyrum/generators/message_generator_spec.rb`, replace the `"AI_MODEL_DEFAULTS constant"` describe block:

```ruby
describe "AI_MODEL_FAMILIES constant" do
  it "maps cloud API providers to family strings" do
    expect(Hyrum::Generators::AI_MODEL_FAMILIES).to include(
      openai: "gpt-mini",
      anthropic: "claude-haiku",
      gemini: "gemini-flash",
      mistral: "mistral-small",
      deepseek: "deepseek"
    )
  end
end

describe "AI_MODEL_LITERALS constant" do
  it "maps local/managed providers to literal model name symbols" do
    expect(Hyrum::Generators::AI_MODEL_LITERALS).to include(
      ollama: :llama3,
      fake: :fake
    )
  end
end
```

**Step 2: Run spec to confirm it fails**

```bash
bundle exec rspec spec/hyrum/generators/message_generator_spec.rb
```

Expected: red — `uninitialized constant Hyrum::Generators::AI_MODEL_FAMILIES`

**Step 3: Update `message_generator.rb`**

Replace the `AI_MODEL_DEFAULTS` constant block:

```ruby
AI_MODEL_FAMILIES = {
  openai:    "gpt-mini",
  anthropic: "claude-haiku",
  gemini:    "gemini-flash",
  mistral:   "mistral-small",
  deepseek:  "deepseek"
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

Remove `AI_MODEL_DEFAULTS` entirely.

**Step 4: Run the full suite to find any remaining references**

```bash
bundle exec rspec
```

Fix any failures caused by `AI_MODEL_DEFAULTS` references in other files (grep for it: `grep -r AI_MODEL_DEFAULTS .`).

**Step 5: Commit**

```bash
git add lib/hyrum/generators/message_generator.rb spec/hyrum/generators/message_generator_spec.rb
git commit -m "refactor: replace AI_MODEL_DEFAULTS with AI_MODEL_FAMILIES and AI_MODEL_LITERALS"
```

---

### Task 3: Add `--model-strategy` CLI flag

**Files:**
- Modify: `lib/hyrum.rb` (add attribute to `CLIOptions`)
- Modify: `lib/hyrum/script_options.rb` (default + flag)
- Modify: `spec/hyrum/script_options_spec.rb` (new cases)

**Step 1: Write failing tests**

Add to `spec/hyrum/script_options_spec.rb` inside `describe "#parse"`:

```ruby
context "with --model-strategy flag" do
  it "parses --model-strategy cheapest" do
    args = %w[-s fake --model-strategy cheapest]
    options = Hyrum::ScriptOptions.new(args).parse
    expect(options[:model_strategy]).to eq(:cheapest)
  end

  it "parses --model-strategy newest" do
    args = %w[-s fake --model-strategy newest]
    options = Hyrum::ScriptOptions.new(args).parse
    expect(options[:model_strategy]).to eq(:newest)
  end

  it "parses --model-strategy stable" do
    args = %w[-s fake --model-strategy stable]
    options = Hyrum::ScriptOptions.new(args).parse
    expect(options[:model_strategy]).to eq(:stable)
  end

  it "defaults model_strategy to :cheapest" do
    args = %w[-s fake]
    options = Hyrum::ScriptOptions.new(args).parse
    expect(options[:model_strategy]).to eq(:cheapest)
  end

  it "rejects invalid strategy" do
    args = %w[-s fake --model-strategy bogus]
    expect {
      Hyrum::ScriptOptions.new(args).parse
    }.to raise_error(Hyrum::ScriptOptionsError, /Invalid argument/)
  end
end
```

**Step 2: Run spec to confirm it fails**

```bash
bundle exec rspec spec/hyrum/script_options_spec.rb
```

Expected: red

**Step 3: Add default to `ScriptOptions#initialize`**

In `lib/hyrum/script_options.rb`, add to the `@options` hash in `initialize`:

```ruby
@options = {
  message: nil,
  validate: false,
  min_quality: 70,
  strict: false,
  show_scores: false,
  model_strategy: :cheapest
}
```

**Step 4: Add the CLI flag in `ScriptOptions#ai_service_options`**

Append to the `ai_service_options` method (after the existing `-d MODEL` block):

```ruby
strategies = %w[cheapest newest stable]
description = "Model selection strategy: #{strategies.join(", ")} (default: cheapest)"
parser.on("--model-strategy STRATEGY", strategies, description) do |strategy|
  options[:model_strategy] = strategy.to_sym
end
```

**Step 5: Add `model_strategy` attribute to `CLIOptions` in `lib/hyrum.rb`**

In the `CLIOptions < Dry::Struct` block, add after the `verbose` attribute:

```ruby
attribute :model_strategy, Types::Coercible::Symbol.default(:cheapest)
```

**Step 6: Run spec to confirm it passes**

```bash
bundle exec rspec spec/hyrum/script_options_spec.rb
```

Expected: green

**Step 7: Run full suite**

```bash
bundle exec rspec
```

Expected: green

**Step 8: Commit**

```bash
git add lib/hyrum.rb lib/hyrum/script_options.rb spec/hyrum/script_options_spec.rb
git commit -m "feat: add --model-strategy CLI flag with cheapest/newest/stable options"
```

---

### Task 4: Wire `ModelResolver` into `set_dynamic_defaults`

**Files:**
- Modify: `lib/hyrum/script_options.rb`
- Modify: `spec/hyrum/script_options_spec.rb`

**Step 1: Write failing tests**

Add to `spec/hyrum/script_options_spec.rb` inside `describe "#parse"`:

```ruby
context "with a cloud API provider and no explicit model" do
  it "resolves the model dynamically via ModelResolver" do
    allow(Hyrum::ModelResolver).to receive(:resolve)
      .with(provider: :anthropic, family: "claude-haiku", strategy: :cheapest)
      .and_return(:"claude-3-haiku-20240307")

    args = %w[-s anthropic -m hello]
    options = Hyrum::ScriptOptions.new(args).parse
    expect(options[:ai_model]).to eq(:"claude-3-haiku-20240307")
  end

  it "raises ScriptOptionsError when ModelResolver cannot find a model" do
    allow(Hyrum::ModelResolver).to receive(:resolve)
      .and_raise(Hyrum::ModelResolver::ModelNotFoundError, "No models found for anthropic/claude-haiku")

    args = %w[-s anthropic -m hello]
    expect {
      Hyrum::ScriptOptions.new(args).parse
    }.to raise_error(Hyrum::ScriptOptionsError, /Model resolution failed/)
  end
end

context "with a literal provider (ollama) and no explicit model" do
  it "uses the literal default without calling ModelResolver" do
    allow(Hyrum::ModelResolver).to receive(:resolve)
    args = %w[-s ollama -m hello]
    options = Hyrum::ScriptOptions.new(args).parse
    expect(options[:ai_model]).to eq(:llama3)
    expect(Hyrum::ModelResolver).not_to have_received(:resolve)
  end
end

context "when model is explicitly provided" do
  it "uses the explicit model without calling ModelResolver" do
    allow(Hyrum::ModelResolver).to receive(:resolve)
    args = %w[-s anthropic -m hello -d my-custom-model]
    options = Hyrum::ScriptOptions.new(args).parse
    expect(options[:ai_model]).to eq(:"my-custom-model")
    expect(Hyrum::ModelResolver).not_to have_received(:resolve)
  end
end
```

**Step 2: Run spec to confirm it fails**

```bash
bundle exec rspec spec/hyrum/script_options_spec.rb
```

Expected: red — resolver not called yet

**Step 3: Update `set_dynamic_defaults`**

Replace the method in `lib/hyrum/script_options.rb`:

```ruby
def set_dynamic_defaults
  return if options[:ai_model]

  service = options[:ai_service]
  strategy = options[:model_strategy]

  if (family = Generators::AI_MODEL_FAMILIES[service])
    options[:ai_model] = ModelResolver.resolve(
      provider: service,
      family: family,
      strategy: strategy
    )
  elsif (literal = Generators::AI_MODEL_LITERALS[service])
    options[:ai_model] = literal
  end
rescue ModelResolver::ModelNotFoundError => e
  raise ScriptOptionsError, "Model resolution failed: #{e.message}"
end
```

**Step 4: Run spec to confirm it passes**

```bash
bundle exec rspec spec/hyrum/script_options_spec.rb
```

Expected: green

**Step 5: Run full suite**

```bash
bundle exec rspec
```

Expected: green

**Step 6: Commit**

```bash
git add lib/hyrum/script_options.rb spec/hyrum/script_options_spec.rb
git commit -m "feat: wire ModelResolver into ScriptOptions default model resolution"
```

---

### Task 5: Smoke-test that family names are valid in the live RubyLLM registry

**Files:**
- Modify: `spec/hyrum/model_resolver_spec.rb`

**Step 1: Append smoke tests at the end of the spec**

Add a new describe block (no mocking — hits the local registry JSON bundled in the gem):

```ruby
describe "AI_MODEL_FAMILIES smoke test (real registry, no network)" do
  Hyrum::Generators::AI_MODEL_FAMILIES.each do |provider, family|
    it "resolves at least one model for #{provider}/#{family}" do
      models = RubyLLM.models.by_provider(provider).by_family(family)
      expect(models).not_to be_empty,
        "Expected RubyLLM registry to contain models for provider=#{provider} family=#{family}. " \
        "Run `bundle update ruby_llm` or check the family name."
    end
  end
end
```

**Step 2: Run to confirm it passes**

```bash
bundle exec rspec spec/hyrum/model_resolver_spec.rb
```

Expected: green. If any family fails, correct the family name in `AI_MODEL_FAMILIES` and re-run.

**Step 3: Run full suite one final time**

```bash
bundle exec rspec
```

Expected: all green

**Step 4: Commit**

```bash
git add spec/hyrum/model_resolver_spec.rb
git commit -m "test: smoke-test AI_MODEL_FAMILIES family names against live RubyLLM registry"
```

---

## Done

All five tasks complete. The implementation should now:
- Dynamically resolve models for openai, anthropic, gemini, mistral, deepseek
- Use `:cheapest` strategy by default (configurable via `--model-strategy`)
- Raise a clear `ScriptOptionsError` if the registry has no match
- Keep literal IDs for ollama, openrouter, vertexai, bedrock, gpustack, fake
- Self-test that family names remain valid each time the suite runs
