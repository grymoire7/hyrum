# frozen_string_literal: true

require "spec_helper"

RSpec.describe Hyrum::JsonExtractor do
  describe ".call" do
    context "when content is already a Hash" do
      it "returns it as-is" do
        input = {"e418" => ["message one", "message two"]}
        expect(described_class.call(input)).to eq(input)
      end
    end

    context "when content is a clean JSON string" do
      it "parses and returns the Hash" do
        input = '{"e418":["message one","message two"]}'
        expect(described_class.call(input)).to eq("e418" => ["message one", "message two"])
      end
    end

    context "when content is wrapped in markdown code fences" do
      it "strips ```json fences and parses" do
        input = "```json\n{\"e418\":[\"message one\"]}\n```"
        expect(described_class.call(input)).to eq("e418" => ["message one"])
      end

      it "strips plain ``` fences and parses" do
        input = "```\n{\"e418\":[\"message one\"]}\n```"
        expect(described_class.call(input)).to eq("e418" => ["message one"])
      end
    end

    context "when JSON is embedded in surrounding prose" do
      it "extracts JSON preceded by preamble text" do
        input = "Here are the messages you requested:\n\n{\"e418\":[\"message one\"]}"
        expect(described_class.call(input)).to eq("e418" => ["message one"])
      end

      it "extracts JSON followed by explanation text" do
        input = "{\"e418\":[\"message one\"]}\n\nNote: these are all unique."
        expect(described_class.call(input)).to eq("e418" => ["message one"])
      end

      it "extracts JSON surrounded by prose on both sides" do
        input = "Sure! Here you go:\n{\"e418\":[\"message one\"]}\nHope that helps!"
        expect(described_class.call(input)).to eq("e418" => ["message one"])
      end
    end

    context "when the content contains no parseable JSON" do
      it "raises JSON::ParserError" do
        expect {
          described_class.call("Sorry, I cannot help with that request.")
        }.to raise_error(JSON::ParserError, /No JSON object found/)
      end
    end
  end
end
