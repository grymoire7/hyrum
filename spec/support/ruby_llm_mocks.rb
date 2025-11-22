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
