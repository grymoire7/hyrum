# Quality Validation System Design

**Date:** 2025-11-23
**Status:** Design approved
**Purpose:** Add AI output quality validation to demonstrate production-ready AI system design and testing expertise

## Overview

This design adds a quality validation system to Hyrum that scores and validates AI-generated message variations. The feature showcases understanding of LLM quality control, complex system testing, and product thinking while fitting naturally into the existing tool.

## Goals

### Primary Goals
- Validate that generated variations achieve Hyrum's Law purpose (same meaning, different surface forms)
- Provide quality feedback to users without breaking existing workflows
- Demonstrate senior engineering skills in AI quality control and system design

### Non-Goals
- Runtime syntax validation (template-based generation ensures syntax correctness)
- Multiple competing quality metrics (causes metric tension)
- Mandatory validation (breaks backwards compatibility)

## Architecture

### System Flow

The validation layer sits between generation and formatting:

```
MessageGenerator (existing)
  → calls AI service
  → returns variations array
  ↓
QualityValidator (new)
  → analyzes variations
  → returns ValidationResult(score, details, passed)
  ↓
Formatter (existing)
  → formats code with optional quality comments
```

### Design Principles

1. **Strategy pattern for validators**: Different validators can be composed without changing core code
2. **Configurable thresholds**: Users control acceptable quality levels via CLI
3. **Non-blocking by default**: Warnings rather than failures, with optional strict mode
4. **Extensible scoring**: Easy to add new quality metrics
5. **Backwards compatible**: Existing usage unchanged, validation opt-in

## Quality Metric: "Useful Variation"

### The Problem

Two naive approaches create tension:
- **Diversity alone**: Variations might differ in meaning ("Server error" vs "Try later")
- **Consistency alone**: Variations might be too similar ("Server error" vs "Server error occurred")

These metrics work against each other and don't capture the real requirement.

### The Solution

A single unified validator that measures **"Useful Variation"**:

**Definition:** Variations should have the SAME meaning but DIFFERENT surface forms

**Measurement:**
- **Semantic similarity** (embeddings comparison): Should be HIGH (>85%)
  - Ensures all variations convey the same core message
  - Uses vector embeddings to measure meaning
- **Lexical diversity** (word overlap, phrasing): Should be MODERATE (30-70% different)
  - Ensures variations use different words/phrases
  - Avoids trivial changes that users might still depend on

**Sweet spot:** Variations cluster tightly in semantic space but spread out in lexical space

**Failure modes detected:**
- **Too similar**: "Server error" vs "Server error occurred" (lexical diversity too low)
- **Too different**: "Server error" vs "Please try again later" (semantic similarity too low)

## Implementation Details

### Semantic Similarity Measurement

**Approach:** Embedding-based comparison

**Rationale:**
- Deterministic results
- Faster than prompt-based validation
- Cheaper (no extra LLM generation calls)
- Interpretable distance metrics

**Implementation:**
- Use LLM provider's embedding API (OpenAI, etc.)
- Calculate cosine similarity between variation embeddings
- Average pairwise similarities for overall score

**Fallback strategy:** For providers without embeddings:
- Simple heuristics: word overlap, sentiment analysis
- Degrade gracefully with warning about reduced accuracy

### Lexical Diversity Measurement

**Approach:** Combination of Jaccard distance on word sets + unique n-gram counting

**Rationale:**
- Pure Ruby, no external dependencies
- Fast computation
- Interpretable results

**Calculation:**
```ruby
diversity_score = 1 - (shared_words / total_unique_words)
```

**Enhancements:**
- Weight longer n-grams more heavily (phrase-level variation)
- Normalize for message length
- Consider stemming for more accurate word comparison

### Architecture Pattern

**Service object pattern:**
```ruby
result = QualityValidator.new(variations, options).validate
```

**Result object pattern:**
```ruby
ValidationResult
  - score: Float (0-100)
  - semantic_similarity: Float (0-100)
  - lexical_diversity: Float (0-100)
  - passed: Boolean
  - details: Hash
  - warnings: Array<String>
```

**Strategy for expansion:**
- Validators composed via strategy pattern
- Easy to add new metrics without changing core
- Each validator contributes to overall score

### Dependencies

**Minimal additions:**
- `matrix` gem (stdlib) for vector math
- Leverage existing `ruby_llm` for embedding calls

**No external dependencies** for core functionality

## CLI Integration

### New Flags

```bash
--validate          # Enable quality validation (default: off)
--min-quality SCORE # Minimum quality score 0-100 (default: 70)
--strict            # Fail on quality issues instead of warning (default: false)
--show-scores       # Include quality metrics in output (default: false)
```

### User Workflows

**Quick usage (existing behavior unchanged):**
```bash
hyrum -s openai -m "Server error" -f ruby
# No validation, works exactly as today
```

**Production usage with validation:**
```bash
hyrum -s openai -m "Server error" -f ruby --validate --min-quality 75
# Validates quality, warns if score < 75, still outputs code
```

**Strict mode for CI/CD:**
```bash
hyrum -s openai -m "Server error" -f ruby --validate --strict
# Exits with error code if validation fails, no output generated
```

### Output Format

When validation is enabled, prepend quality report as comments in target language:

```ruby
# Quality Score: 82/100
# - Semantic similarity: 94% (variations preserve meaning)
# - Lexical diversity: 68% (good variation in wording)
#
# frozen_string_literal: true
# [rest of generated code...]
```

**Benefits:**
- Quality info embedded in generated code
- Comments automatically formatted for target language
- Developers see quality metrics alongside code
- No separate reporting mechanism needed

## Testing Strategy

### Unit Tests

**QualityValidator:**
- Known good variations (high semantic similarity, good diversity) → Pass
- Too similar variations ("Error" vs "Error occurred") → Fail lexical diversity
- Too different variations ("Error" vs "Success") → Fail semantic similarity
- Edge cases: empty variations, single variation, identical variations

**Embedding integration:**
- Mock embedding API responses for deterministic tests
- Test fallback behavior when embeddings unavailable
- Verify cosine similarity calculations

**Lexical diversity:**
- Test Jaccard distance calculation
- Test n-gram counting
- Test normalization edge cases

### Integration Tests

**End-to-end validation:**
- Generate real variations with test LLM
- Run validation on output
- Verify quality scores in expected ranges

**CLI flag combinations:**
- `--validate` alone
- `--validate --strict`
- `--validate --show-scores`
- `--min-quality` threshold enforcement

### Real-world Testing

**Manual quality checks:**
- Generate variations for common error messages
- Human evaluation of quality scores
- Calibrate thresholds based on actual LLM behavior

## Success Metrics

**Portfolio demonstration:**
- Shows understanding of LLM quality challenges
- Demonstrates testing strategy for non-deterministic systems
- Exhibits product thinking (backwards compatibility, optional features)
- Showcases architecture skills (clean separation, extensibility)

**Technical metrics:**
- Quality validator runs in <100ms (excluding embedding API calls)
- Zero false positives on good variations in test suite
- Catches >90% of problematic variations in test cases

## Future Enhancements

**Not in scope for initial implementation, but natural extensions:**

1. **Custom quality metrics**: Allow users to define their own validators
2. **Quality trending**: Track quality over time, detect provider degradation
3. **Provider comparison**: Compare quality across different LLM providers
4. **Automatic regeneration**: If quality fails, retry with different prompt
5. **Learning from feedback**: Improve thresholds based on user accept/reject patterns

## Open Questions

None - design is approved and ready for implementation.
