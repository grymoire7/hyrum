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
platform that cut costs by 10x, reduced code complexity from 12 to 1,
and added quality validation for AI-generated content.

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

## Validating non-deterministic output

Getting AI to generate message variations was the easy part. The harder
question was: how do you know if the variations are any good?

This is where Hyrum gets interesting as a portfolio project. Anyone can
wire up an AI API and generate text. Building a system that validates
the quality of non-deterministic output requires deeper thinking about
what "quality" even means in this context.

### Defining useful variation

A good variation needs two properties:

1. **Semantic similarity** - It preserves the original message's meaning
2. **Lexical diversity** - It uses different wording than other variations

These goals exist in tension. Perfect similarity means identical text.
Perfect diversity means unrelated messages. The sweet spot is variations
that mean the same thing but say it differently.

I implemented a quality validation system that measures both metrics
and combines them into an overall quality score. This lets you validate
generated variations automatically, ensuring they achieve Hyrum's Law
goal of preventing dependency on exact wording.

### The initial design mistake

My first implementation compared variations to each other. Generate
five variations, measure how similar they are as a group, done. This
seemed logical until I tested it.

The problem: variations could be highly similar to each other but
completely different from the original message. A set of variations
about network timeouts would score well even if the original message
was about authentication failures. They were diverse from each other,
but wrong.

The fix was obvious in hindsight: compare each variation to the
original message, not to other variations. Semantic similarity measures
how well each variation preserves the user's intent. Lexical diversity
measures how much the variations differ from each other. Two separate
concerns, two separate comparisons.

### Semantic similarity with embeddings

Measuring semantic similarity requires understanding meaning, not just
matching words. "Server error" and "Internal server failure" share
minimal text but convey the same concept. Simple string comparison
would fail.

The solution: embedding models. These convert text into high-dimensional
vectors where semantically similar content clusters together. Calculate
the cosine similarity between the original message's embedding and each
variation's embedding, and you have a numeric score for how well meaning
is preserved.

I designed this to be provider-agnostic from the start, learning from
the earlier migration experience. The validator uses `RubyLLM.embed()`
which works with any provider that supports embeddings (OpenAI, Google,
etc.). When embeddings aren't available, it falls back to a simpler
word overlap heuristic.

This graceful degradation was important. Users without embedding access
still get validation, just with reduced accuracy. The feature doesn't
silently fail or block users.

### API design for optional features

Quality validation needed to be opt-in. The core workflow is "generate
variations and use them." Adding validation steps would slow things down
and require configuration. It needed to enhance the workflow without
disrupting it.

The CLI design reflects this:

```bash
# Basic usage - no validation
hyrum -s openai -m "Server error" -f ruby

# Opt into validation
hyrum -s openai -m "Server error" -f ruby --validate

# Use in CI/CD with strict mode
hyrum -s openai -m "Server error" -f ruby --validate --strict --min-quality 75
```

Validation is off by default. Enable it when you want quality metrics.
Use `--strict` to fail builds when quality is too low. Use `--show-scores`
to include metrics in generated output.

Each flag serves a specific use case without cluttering the happy path.
This is backward compatible and makes the feature discoverable through
`--help` without overwhelming new users.

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

### User feedback catches design flaws early

My initial quality validation design seemed sound in theory. It measured
variation quality as a group property. But the first test revealed the
flaw: variations could be similar to each other while being completely
unrelated to the original message.

This is why you test with real examples before building the whole system.
The fix (comparing to the original message) was trivial to implement
early. It would have been painful to retrofit later after building an
entire validation pipeline on the wrong assumption.

The lesson: design mistakes are inevitable. What matters is catching them
before they become weight-bearing walls in your architecture.

### Graceful degradation beats hard dependencies

Embedding models provide superior semantic similarity measurement. But
requiring them would block users whose AI providers don't support
embeddings. The word overlap fallback isn't as accurate, but it's
better than nothing.

This pattern appears throughout the gem. Can't access embeddings? Use
heuristics. Provider doesn't support structured output? Parse text.
Each graceful degradation expands the set of valid configurations.

The alternative is failing fast with clear errors. Both approaches are
valid, but for a tool that works across many providers, degradation
creates a better experience than strict requirements.

### Validation changes what "done" means

Before quality validation, "done" meant "generates variations." After,
it meant "generates variations that preserve meaning while varying
wording." This shift changed the entire value proposition.

The interesting part is that validation makes the AI output more
trustworthy without requiring a better AI model. Same model, same cost,
but now you have quantitative confidence in the results. That's the
leverage of good metrics.

## The result

Hyrum now supports 11 AI providers (OpenAI, Anthropic, Gemini, Ollama,
Mistral, DeepSeek, Perplexity, OpenRouter, Vertex AI, AWS Bedrock,
GPUStack) through a unified interface. The codebase is simpler,
tests are faster, and costs are 10x lower.

Quality validation adds confidence without complexity. Generate variations,
validate they preserve meaning while varying wording, and integrate the
results into your codebase with quantitative quality metrics. The
validation system works across all providers and degrades gracefully
when embeddings aren't available.

But the real achievement isn't the feature list. It's that the
architecture can accommodate new providers and capabilities without
increasing complexity. When ruby_llm adds support for a new provider,
Hyrum gets it for free. When embedding models improve, quality
validation automatically benefits. That's the payoff of choosing the
right abstractions.

The project is [open source on GitHub](https://github.com/grymoire7/hyrum).
If you're dealing with Hyrum's Law in your own APIs, or you're just
curious about the implementation details, check it out.

