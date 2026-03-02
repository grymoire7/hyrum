# frozen_string_literal: true

require "spec_helper"

RSpec.describe Hyrum::Generators::MessageGenerator do
  describe ".create" do
    it "returns FakeGenerator for fake service" do
      options = {ai_service: :fake}
      generator = described_class.create(options)
      expect(generator).to be_a(Hyrum::Generators::FakeGenerator)
    end

    it "returns AiGenerator for openai service" do
      options = {ai_service: :openai, ai_model: :"gpt-4o-mini", message: "test", key: :e418, number: 3, verbose: false}
      generator = described_class.create(options)
      expect(generator).to be_a(Hyrum::Generators::AiGenerator)
    end

    it "returns AiGenerator for anthropic service" do
      options = {ai_service: :anthropic, ai_model: :"claude-haiku-20250514", message: "test", key: :e418, number: 3, verbose: false}
      generator = described_class.create(options)
      expect(generator).to be_a(Hyrum::Generators::AiGenerator)
    end

    it "returns AiGenerator for gemini service" do
      options = {ai_service: :gemini, ai_model: :"gemini-2.0-flash-exp", message: "test", key: :e418, number: 3, verbose: false}
      generator = described_class.create(options)
      expect(generator).to be_a(Hyrum::Generators::AiGenerator)
    end

    it "returns AiGenerator for ollama service" do
      options = {ai_service: :ollama, ai_model: :llama3, message: "test", key: :e418, number: 3, verbose: false}
      generator = described_class.create(options)
      expect(generator).to be_a(Hyrum::Generators::AiGenerator)
    end
  end

  describe "AI_SERVICES constant" do
    it "includes all supported providers" do
      expect(Hyrum::Generators::AI_SERVICES).to include(
        :openai, :anthropic, :gemini, :ollama, :mistral,
        :deepseek, :perplexity, :openrouter, :vertexai,
        :bedrock, :gpustack, :fake
      )
    end
  end

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
end
