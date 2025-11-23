---
title: Building a Ruby CLI gem for Hyrum's Law
date: 2025-11-20
draft: true
hideLastModified: true
showInMenu: false
summaryImage: "hryum_top.png"
featuredImage: "hryum_top.png"
featuredImagePreview: ""
tags: ["AI", "Portfolio", "Ruby", "Gem", "CLI"]
summary: "A deep dive into creating a Ruby CLI gem that helps developers cope with Hyrum's Law in their projects."
claude: >
  This post should be in the style of casual expertise -- like a friendly
  and talented teacher explaining complex topics with simple language and examples.
  It is not so casual that it feels unprofessional. We do not use words like "stuff", "cool", or "yeah".
  Use simple language. Not "flowery" or overly dramatic, but sill compelling and easy to read.
  My writing is more like an entertaining conference talk and less like a business whitepaper.
  I use sentence case for headings and subheadings rather than title case.
  Please wrap paragraphs at around 80 characters for readability.
---

# Building a Ruby CLI gem for Hyrum's Law

When you build a public API, users will depend on behaviors you never
intended to guarantee. It's called Hyrum's Law, and it's particularly
tricky when it comes to error messages. Change "User not found" to "No
such user exists" and someone's regex breaks in production at 2am.

I built Hyrum to solve this. It's a Ruby CLI gem that uses AI to
generate variations of status messages, ensuring users never become
dependent on exact wording. But more interesting than what it does is
how it evolved from a single-provider tool into a multi-provider
platform that cut costs by 10x and reduced code complexity from 12 to 1.

## The problem with predictable messages

[Hyrum's Law](https://www.laws-of-software.com/laws/hyrum/) states that
all observable behaviors of your system will be depended on by somebody.
This creates a dilemma for API designers: you want clear, consistent
error messages, but you don't want users parsing them as if they were
structured data.

Error codes help with this. Return `404` or `E_NOT_FOUND` and the
message text can evolve independently. But this only works if you're
disciplined about using codes for everything that matters. In practice,
some context lives in the message text, and someone will parse it.

The traditional solution is thorough documentation warning against this.
The pragmatic solution is accepting that some percentage of users will
do it anyway. My solution was to make the messages unpredictable by
design.

## Building the initial solution

The first version was straightforward. The gem takes a message like "The
server refuses the attempt to brew coffee with a teapot" and generates
code in your language of choice (Ruby, JavaScript, Python, Java, or
JSON) that returns variations at random:

```ruby
module Messages
  MESSAGES = {
    e418: [
      "Invalid Brewing Method",
      "Teapot not designed for coffee brewing",
      "Please use a suitable brewing device"
    ]
  }.freeze

  def self.message(key)
    MESSAGES[key].sample
  end
end
```

I started with OpenAI's API via the `ruby-openai` gem. It worked well
for the core use case. But eventually, two problems emerged.

First, cost. Running `gpt-4` for simple message generation was using a
chainsaw to cut butter. Second, vendor lock-in. Some projects had
Anthropic credits, others used local Ollama models. I needed to support
multiple providers without maintaining provider-specific code paths.

## The migration decision

I had three options:

1. Build custom adapters for each provider
2. Find an abstraction layer that handled the differences
3. Accept the limitation and move on

Building custom adapters would give me complete control, but at the cost
of maintaining provider-specific logic as APIs evolved. Option three was
tempting but unsatisfying.

I chose option two, migrating to
[ruby_llm](https://github.com/crmne/ruby_llm). More than
swapping dependencies, this was a fundamental architecture change that
would affect testing strategy, error handling, configuration, and the
public API.

## Key technical decisions

### Cost optimization through model selection

The most impactful decision was switching from premium to budget models.
For Anthropic, this meant `claude-sonnet-4` to `claude-haiku-20250514`,
a roughly 10x cost reduction.

This wasn't about being cheap. It was about matching model capability to task
complexity. Generating three variations of "Resource not found" doesn't require
deep reasoning. Budget models handle it perfectly well. The quality remained
identical while costs dropped by an order of magnitude.

### Testing strategy: mock at the right level

The original implementation used VCR to record HTTP interactions. This
is a common pattern, but it had problems:

- Maintaining cassettes for 10+ providers would be tedious
- Tests would break when ruby_llm changed request formats
- We would be testing ruby_llm's HTTP implementation, not our code

The better approach: mock at the ruby_llm interface level. Instead of
recording HTTP traffic, we mock `RubyLLM.chat()` directly. One mock
setup works for all providers. Tests are faster, more maintainable, and
focused on our actual logic.

This eliminated the need for VCR and WebMock entirely, removing two
dependencies. 🎊

As an additional safeguard, I set up a GitHub Actions workflow that runs
the full test suite on every push. This catches regressions before they
reach main and provides confidence when accepting contributions. It's a
small addition that pays dividends in long-term maintainability.

### Code simplification through extraction

`FakeGenerator` started at 298 lines with embedded message data.
Extracting the messages to an external JSON file and refactoring the
logic brought it down to 36 lines. That's an 88% reduction.

But the real win was in `AiGenerator`. By letting ruby_llm handle
provider differences, the cyclomatic complexity dropped from 12 to 1.
Twelve decision points (checking provider types, handling edge cases)
collapsed into a single code path.

This is the value of a good abstraction layer. It reduces the
lines of code, sure, but it also reduces the number of things you have to think
about.

### Breaking changes as a design tool

The migration required environment variable changes:
- `OPENAI_ACCESS_TOKEN` → `OPENAI_API_KEY`
- `OLLAMA_URL` → `OLLAMA_API_BASE`

I considered adding migration helpers to detect old variables and warn
users. But the gem was pre-1.0 with minimal adoption. Adding complexity
for hypothetical users would hurt future maintainability more than it
helped current users.

The cleaner approach: document the breaking changes clearly, provide a
migration guide, and move forward with consistent naming. Sometimes the
right trade-off is accepting short-term pain for long-term simplicity.

## Implementation approach

I followed a disciplined TDD approach for the migration:

1. Write failing tests for `AiGenerator`
2. Implement minimal code to pass
3. Add error handling tests
4. Implement error handling
5. Verify across multiple providers

Each commit represented a logical unit of work with a clear purpose. The
git history tells a story: dependency updates, test infrastructure, new
generator implementation, factory updates, cleanup, documentation.

This matters for maintainability. Six months from now, when I need to
add a new provider or debug an edge case, the git history explains not
only what changed but why.

## What I learned

### Shipping a Ruby gem is more accessible than I expected

I hadn't published a gem before this project. The Ruby ecosystem makes
it surprisingly straightforward: follow conventions for directory
structure, add a gemspec, and `gem build` handles the rest. RuboCop
enforces community standards, and RSpec provides solid testing patterns.

Most of the learning curve wasn't in the tooling. It was in the design
decisions around versioning, breaking changes, and API stability. Understanding
when to bump major vs minor versions, when breaking changes are acceptable, and
how much backward compatibility to maintain. These are judgment calls that come
with experience, not documentation per se.

### Abstractions have a cost and a benefit

Ruby_llm's abstraction eliminated provider-specific code paths. But it
also added a dependency and gave up some provider-specific features
(like Anthropic's prompt caching). The trade-off made sense because the
gem's core use case doesn't need advanced features. Your mileage will
vary.

### Model selection is a design decision

Defaulting to budget models wasn't about minimizing costs. It was about
right-sizing capability to task complexity. When your task genuinely
needs advanced reasoning, use advanced models. When it doesn't, you're
paying for capability you're not using.

### Testing at the right abstraction level matters

Mocking at the HTTP level tests the wrong thing. Mocking at the library
interface level tests your code. The latter is almost always better
unless you're specifically testing HTTP behavior.

### Breaking changes are acceptable in context

Pre-1.0 software with limited adoption is the right time to make
breaking changes. Adding backward compatibility for a handful of users
creates technical debt that affects every future user. Sometimes the
generous thing is to break things cleanly.

## The result

Hyrum now supports 11 AI providers (OpenAI, Anthropic, Gemini, Ollama,
Mistral, DeepSeek, Perplexity, OpenRouter, Vertex AI, AWS Bedrock,
GPUStack) through a unified interface. The codebase is simpler,
tests are faster, and costs are 10x lower.

But the real achievement isn't the feature list. It's that the
architecture can accommodate new providers without increasing complexity.
When ruby_llm adds support for a new provider, Hyrum gets it for free.
That's the payoff of choosing the right abstraction.

The project is [open source on GitHub](https://github.com/grymoire7/hyrum).
If you're dealing with Hyrum's Law in your own APIs, or you're just
curious about the implementation details, check it out.

