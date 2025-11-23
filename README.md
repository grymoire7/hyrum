# Hyrum's Message Generator

✨ A multi-language code generator to cope with Hyrum's law ✨

Hyrum's message generator (hyrum) generates a method in the chosen language that
returns one of several variations of a provided message at random.

![Tests](https://github.com/grymoire7/hyrum/actions/workflows/ruby.yml/badge.svg?branch=main)
![Ruby Version](https://img.shields.io/badge/Ruby-3.3.5-green?logo=Ruby&logoColor=red&label=Ruby%20version&color=green)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/grymoire7/hyrum/blob/main/LICENSE.txt)

## Explanation
[Hyrum's law][hd] states that all observable behaviors of your system will be
depended on by somebody. Some nice examples can be found [here][he].

One example that seems a little more difficult to handle is the case where a
status/error message is being returned to the user. How can you vary the message
so the user doesn't become dependent on the exact wording of the message?
Also, we don't want to spend a lot of time writing variations of the same message.

This is the use case Hyrum tries to solve. It uses an AI service (openai,
ollama, etc.) to generate variations of a provided message. The generated
variations are also formatted in the language/format of your choice (ruby,
json, etc.). This code can then be used in your project to ensure messages are
no longer static, improving your api design.

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

## Usage

```
❯ hyrum --help # OR from the repo as `./exe/hyrum --help`
Usage: hyrum [options]
    -v, --[no-]verbose               Run verbosely
    -f, --format FORMAT              Output format. Supported formats are:
                                     ruby, javascript, python, java, text, json
    -m, --message MESSAGE            Status message
    -k, --key KEY                    Message key
    -s, --service SERVICE            AI service: one of openai, ollama, fake
    -d, --model MODEL                AI model: must be a valid model for the selected service
    -h, --help                       Show this message
        --version                    Show version
```

## Installation
Install the gem and add to the application's Gemfile by executing:

    $ bundle add hyrum

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install hyrum

## Run without configuration
Hyrum normally requires configuration to access an AI service provider. However,
if you want to see output quickly, you can use the `-s fake` option to use a fake
service provider that will generate stock responses.

```bash
hyrum -s fake -f ruby -k "404" -n 5
```

You don't even need to install the gem to use Hyrum, fake service provider or not.
You can run the executable directly from a cloned repository.

```bash
./bin/hyrum -s fake -f ruby -m "anything here"
```

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

## Supported formats and AI services

**Formats:** ruby, javascript, python, java, text, json

**AI Services:** openai, anthropic, gemini, ollama, mistral, deepseek, perplexity,
openrouter, vertexai, bedrock, gpustack, fake

See [Configuration](#configuration) for setup details for each service.

## Compatibility

This gem is compatible with Ruby 3.1 or greater.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake spec` to run the tests.

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push
git commits and the created tag, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/grymoire7/hyrum. This project is intended to be a safe,
welcoming space for collaboration, and contributors are expected to adhere to the
[code of conduct](https://github.com/grymoire7/hyrum/blob/main/CODE_OF_CONDUCT.md).

[hd]: https://www.laws-of-software.com/laws/hyrum/
[he]: https://abenezer.org/blog/hyrum-law-in-golang
