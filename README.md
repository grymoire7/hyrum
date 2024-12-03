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

```bash
hyrum --service openai --key e418 --format ruby \
      --message "The server refuses the attempt to brew coffee with a teapot"
```

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
hyrum -s fake -f ruby -m "anything here"
```

You don't even need to install the gem to use Hyrum, fake service provider or not.
You can run the executable directly from a cloned repository.

```bash
./exec/hyrum -s fake -f ruby -m "anything here"
```

## Configruation

### OpenAI (`--service openai`)
Hyrum requires an OpenAI API token to access the language models. The API token should be
set as an environment variable as shown below.

```bash
export OPENAI_ACCESS_TOKEN=your_open_ai_token
```

If you specify the `openai` service but no model, Hyrum will use the `gpt-o4-mini`.

### Ollama (`--service ollama`)
If you specify the `ollama` service, Hyrum will attempt to use the Ollama API
running at `http://localhost:11434`. You can set the `OLLAMA_URL` environment
variable to specify a different URL.

Make sure your ollama server is running before using the `ollama` service.

```bash
ollama serve
```

Use `ollama list` to see the available models. For more information on using
ollama and downloading models, see the [ollama repository](http://ollama.com).

## Supported formats and AI services

See [Usage](#usage) for a list of supported formats and AI services.

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
