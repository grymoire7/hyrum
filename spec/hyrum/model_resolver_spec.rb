# frozen_string_literal: true

require "spec_helper"

RSpec.describe Hyrum::ModelResolver do
  let(:cheap_model) { instance_double(RubyLLM::Model::Info, id: "cheap-model", input_price_per_million: 0.25, created_at: Time.new(2024, 1, 1)) }
  let(:mid_model) { instance_double(RubyLLM::Model::Info, id: "mid-model", input_price_per_million: 1.0, created_at: Time.new(2024, 6, 1)) }
  let(:pricey_model) { instance_double(RubyLLM::Model::Info, id: "pricey-model", input_price_per_million: 3.0, created_at: Time.new(2024, 3, 1)) }
  let(:models) { [cheap_model, mid_model, pricey_model] }

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

RSpec.describe "AI_MODEL_FAMILIES smoke test (real registry, no network)" do
  Hyrum::Generators::AI_MODEL_FAMILIES.each do |provider, family|
    it "resolves at least one model for #{provider}/#{family}" do
      models = RubyLLM.models.by_provider(provider).by_family(family)
      expect(models).to be_any,
        "Expected RubyLLM registry to contain models for provider=#{provider} family=#{family}. " \
        "Run `bundle update ruby_llm` or check the family name."
    end
  end
end
