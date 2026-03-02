# StandardRB Migration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace RuboCop with StandardRB, remove all inline linter annotations, and enforce style via a pre-commit hook.

**Architecture:** Swap the gem, delete the custom rubocop config, strip dead inline annotations, and install a pre-commit hook copied from the jojo project. No lint step in Rakefile or CI — style is enforced at commit time.

**Tech Stack:** Ruby, StandardRB (`standard` gem), git hooks

**Design doc:** `docs/plans/2026-03-01-standardrb-migration-design.md`

---

### Task 1: Swap rubocop for standard in Gemfile

**Files:**
- Modify: `Gemfile`

**Step 1: Replace the gem**

In `Gemfile`, change:
```ruby
  # Static analysis for code quality [https://rubocop.org/]
  gem "rubocop", require: false
```
to:
```ruby
  # Static analysis for code quality [https://github.com/testdouble/standard]
  gem "standard", require: false
```

**Step 2: Install**

```bash
bundle install
```

Expected: Gemfile.lock updated; `rubocop` replaced by `standard` and its dependencies.

**Step 3: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "chore: replace rubocop with standard gem"
```

---

### Task 2: Remove .rubocop.yml and verify compliance

**Files:**
- Delete: `.rubocop.yml`
- Create (only if needed): `.standard.yml`

**Step 1: Delete the rubocop config**

```bash
rm .rubocop.yml
```

**Step 2: Run standardrb**

```bash
bundle exec standardrb
```

Expected: Clean pass (exit 0). Since `standardrb --fix` was already run (commit 315be50), the codebase should already comply.

If there are failures that can't be auto-fixed, create `.standard.yml` with targeted overrides:

```yaml
# .standard.yml — only add entries if standardrb reports non-auto-fixable offenses
ignore:
  - '**/*':
    - CopName  # reason
```

**Step 3: Commit**

```bash
# If .standard.yml was not needed:
git add -u
git commit -m "chore: remove .rubocop.yml"

# If .standard.yml was needed:
git add -u .standard.yml
git commit -m "chore: remove .rubocop.yml, add minimal .standard.yml"
```

---

### Task 3: Remove inline rubocop:disable annotations

All four disabled methods use `Metrics/MethodLength`, which standard doesn't enforce — these are dead code.

**Files:**
- Modify: `lib/hyrum.rb` (lines 123 and 171)
- Modify: `lib/hyrum/generators/ai_generator.rb` (lines 66 and 82)
- Modify: `lib/hyrum/script_options.rb` (lines 24, 40, 128, and 146)

**Step 1: Remove annotations from lib/hyrum.rb**

Delete these two lines:
```ruby
  # rubocop:disable Metrics/MethodLength   # line 123
```
```ruby
  # rubocop:enable Metrics/MethodLength    # line 171
```

**Step 2: Remove annotations from lib/hyrum/generators/ai_generator.rb**

Delete these two lines:
```ruby
      # rubocop:disable Metrics/MethodLength   # line 66
```
```ruby
      # rubocop:enable Metrics/MethodLength    # line 82
```

**Step 3: Remove annotations from lib/hyrum/script_options.rb**

Delete all four lines:
```ruby
    # rubocop:disable Metrics/MethodLength   # line 24
```
```ruby
    # rubocop:enable Metrics/MethodLength    # line 40
```
```ruby
    # rubocop:disable Metrics/MethodLength   # line 128
```
```ruby
    # rubocop:enable Metrics/MethodLength    # line 146
```

**Step 4: Verify no annotations remain**

```bash
grep -r "rubocop:disable\|rubocop:enable" lib/ spec/
```

Expected: No output.

**Step 5: Run standardrb and tests**

```bash
bundle exec standardrb && bundle exec rake
```

Expected: No offenses; all specs pass.

**Step 6: Commit**

```bash
git add lib/hyrum.rb lib/hyrum/generators/ai_generator.rb lib/hyrum/script_options.rb
git commit -m "chore: remove dead rubocop:disable annotations"
```

---

### Task 4: Install pre-commit hook and document it

**Files:**
- Create: `.git/hooks/pre-commit` (not tracked by git)
- Modify: `CLAUDE.md`

**Step 1: Copy the hook from jojo**

```bash
cp /Users/tracy/projects/jojo/.git/hooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

**Step 2: Verify the hook content**

```bash
cat .git/hooks/pre-commit
```

Expected output:
```sh
#!/bin/sh
# Run Standard Ruby auto-fix before committing
# This ensures all commits follow Standard Ruby style
# Assumption: https://github.com/testdouble/standard is in your Gemfile

set -e

rubyfiles=$(git diff --cached --name-only --diff-filter=ACM "*.rb" "Gemfile" | tr '\n' ' ')
[ -z "$rubyfiles" ] && exit 0

# Standardize all ruby files
echo "💅 Formatting staged Ruby files with standardrb ($(echo $rubyfiles | wc -w | awk '{print $1}') total)"
echo "$rubyfiles" | xargs bundle exec standardrb --fix

# Add back the modified/prettified files to staging
echo "$rubyfiles" | xargs git add

exit 0
```

**Step 3: Document the hook in CLAUDE.md**

Add a "Setup" section to `CLAUDE.md`:

```markdown
## Setup

After cloning, install the pre-commit hook to auto-format staged Ruby files with standardrb:

```bash
cp /path/to/hook .git/hooks/pre-commit   # see docs/plans/2026-03-01-standardrb-migration.md
chmod +x .git/hooks/pre-commit
```
```

Actually, store the hook source in the repo so the install step can reference it directly. Add to CLAUDE.md:

```markdown
## Setup

After cloning, install the StandardRB pre-commit hook:

```bash
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/sh
set -e
rubyfiles=$(git diff --cached --name-only --diff-filter=ACM "*.rb" "Gemfile" | tr '\n' ' ')
[ -z "$rubyfiles" ] && exit 0
echo "Formatting staged Ruby files with standardrb"
echo "$rubyfiles" | xargs bundle exec standardrb --fix
echo "$rubyfiles" | xargs git add
exit 0
EOF
chmod +x .git/hooks/pre-commit
```
```

**Step 4: Commit the CLAUDE.md update**

```bash
git add CLAUDE.md
git commit -m "docs: document pre-commit hook setup for standardrb"
```

---

### Task 5: Final verification

**Step 1: Run full suite**

```bash
bundle exec standardrb && bundle exec rake
```

Expected: No offenses; all specs pass.

**Step 2: Smoke-test the hook**

Make a trivial style change to a Ruby file, stage it, and commit:

```bash
# Add a trailing space to any .rb file, then stage it
git add <that file>
git commit -m "test: smoke test pre-commit hook"
# Verify the hook ran and fixed/re-staged the file
```

Then revert the test commit:

```bash
git revert HEAD --no-edit
```
