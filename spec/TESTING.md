# Testing Guide

## Running Tests

```bash
docker compose -f docker-compose.test.yml up --abort-on-container-exit --exit-code-from test
```

Tests run inside Docker against a real PostgreSQL database. Do **not** run `rspec` directly on the host — Redmine is only available inside the container.

The rspec command the container runs:
```bash
bundle exec rspec plugins/redmine_github/spec/ -I spec -I plugins/redmine_github/spec
```

---

## Test Infrastructure

| Layer | Tool | Notes |
|-------|------|-------|
| Integration / feature specs | Capybara + `rack_test` driver | No browser, no JS |
| Database cleanup | DatabaseCleaner | `:truncation` for `type: :feature`, `:transaction` otherwise |
| Factories | FactoryBot | Lives in `spec/factories/` |
| Capybara config | `spec/support/capybara.rb` | Auto-loaded by `spec/rails_helper.rb` |
| CI rails_helper | `.github/ci/rails_helper.rb` | Copied to `redmine/spec/rails_helper.rb` at test time |

**Do NOT add `gem 'capybara'` to `Gemfile.local`** — Redmine 6.0-stable already declares `capybara >= 3.39`. Adding it again causes a Bundler conflict.

---

## Feature Spec Requirements

### Project must have `redmine_github` module enabled

Without this, every request returns 403.

```ruby
# In your spec:
let(:project) { create(:project, :with_redmine_github) }

# Defined in spec/factories/projects.rb:
trait :with_redmine_github do
  after(:create) { |p| p.enabled_modules.create!(name: 'redmine_github') }
end
```

### Login before visiting any page

```ruby
before { login_as(admin) }
```

`login_as` is defined in `spec/support/auth_helpers.rb` — it sets the session directly without going through the login form.

### Admin user has Japanese locale (`language: 'ja'`)

The default `:admin_user` factory sets `language: 'ja'`. This affects:
- Flash messages and UI text may appear in Japanese for Redmine-standard strings
- Plugin-defined strings (flash notices like "QA approval recorded.") are always English
- **Do NOT use `time_tag ..., format: :short`** in views — it crashes on the ja locale (fixed in `pm_dashboard/index.html.erb`; use `format_time()` instead)

---

## Key Model Gotchas

### ReleaseApproval — must pre-create records

`ApprovalWorkflow#qa_approval` calls `ReleaseApproval.find_or_create_by(version_id:, role:)` without a `user_id`. Since `user_id NOT NULL`, the create attempt fails validation and returns an unsaved record with `status: 'pending'` (Rails picks up the DB default).

**Result:** The approval buttons (`Approve` / `Reject`) appear on the PM Dashboard even without pre-created records, but calling the approval action endpoints will succeed only if a saved record exists.

**Always pre-create approvals in tests that click Approve/Reject:**

```ruby
ReleaseApproval.create!(version: sprint, role: 'QA', status: 'pending', user: admin)
ReleaseApproval.create!(version: sprint, role: 'PM', status: 'pending', user: admin)
```

### ReleaseApproval enum — use string keys, not DB values

```ruby
enum role:   { qa: 'QA', pm: 'PM' }
enum status: { pending: 'pending', approved: 'approved', rejected: 'rejected' }
```

Create with: `role: 'QA'` or `role: :qa` — both accepted by Rails string enums.

### QaSignoff vs ReleaseApproval — two separate approval models

- `ReleaseApproval` — used by the ApprovalWorkflow / PM Dashboard buttons
- `QaSignoff` — used by `QaGateStats#signoff_ok` and `ReleaseReadinessGate`

They are **not linked**. Approving via `ReleaseApproval` does NOT update `QaSignoff`. This means `qs[:signoff_ok]` stays false even after QA approves via the dashboard button. The gate status is determined by metrics + QaSignoff, not by ReleaseApproval.

### PM Dashboard banner state machine

| Condition | Banner |
|-----------|--------|
| `rg[:ready] && chain_complete` | ✅ `pm-go` (READY FOR PRODUCTION) |
| `(rg[:ready] \|\| rg[:risky]) && (qa_pending \|\| pm_pending)` | ⏳ `pm-awaiting` (AWAITING APPROVAL) |
| `rg[:risky] \|\| qa_rejected \|\| pm_rejected` | ⚠ `pm-risky` (RISKY) |
| else | ✗ `pm-nogo` (NOT READY) |

`pm-nogo` only shows when `rg[:blocked]` is true, which requires open **High** or **Immediate** priority issues.

To test NOT READY:
```ruby
let(:high_priority) { create(:issue_priority, name: 'High') }
create_list(:issue, 5, project: project, status: open_status,
            priority: high_priority, fixed_version: sprint)
```

### GitHub Metrics page — requires a GitHub repository

The versions table only renders when `@github_repos` is not empty. Without a `Repository::Github` record, the page shows a "no repos" message.

```ruby
let!(:repo) { create(:github_repository, project: project) }
```

The factory skips the `bare_clone` callback to avoid filesystem operations:
```ruby
before(:create) { Repository::Github.skip_callback(:create, :after, :bare_clone) }
after(:create)  { Repository::Github.set_callback(:create, :after, :bare_clone) }
```

---

## Bugs Fixed During E2E Setup

| File | Bug | Fix |
|------|-----|-----|
| `lib/redmine_github/approval_workflow.rb` | `qa_can_approve?` called `user.has_role?(:qa_tester)` first — method doesn't exist in Redmine, raises `NoMethodError` before `admin?` short-circuit | Reordered: `user.admin? \|\| user.groups...` |
| `app/views/redmine_github/pm_dashboard/index.html.erb` | `time_tag ..., format: :short` raises `ArgumentError` on Japanese locale | Replaced with `format_time()` (Redmine helper) |
| `app/views/redmine_github/pm_dashboard/index.html.erb` | No banner state for rejected approvals | Added `qa_rejected \|\| pm_rejected` → `pm-risky` branch |

## What WAS Added in This Session

### New Spec Files

| File | Type | Covers |
|------|------|--------|
| `spec/requests/webhooks_spec.rb` | request | `pull_request` opened, merged, dedup, unknown event, bad signature |
| `spec/requests/qa_signoffs_spec.rb` | request | create, idempotent create, approve, reject, anonymous redirect |
| `spec/features/project_thresholds_spec.rb` | feature | renders form, valid save, invalid save shows errors |
| `spec/factories/approval_logs.rb` | factory | `ApprovalLog` with version/user/action/role/status/notes |
| `spec/features/pm_dashboard_spec.rb` | feature | +2 audit trail scenarios (with logs / without logs) |

### Application Bug Fixed

`app/controllers/redmine_github/qa_signoffs_controller.rb` — `version_path` called
`project_version_path(@project, @version)` which **does not exist** in Redmine 6.0-stable routes.
Fixed to `project_versions_path(@project)`.

---

## Gotchas for Future Webhook Tests

### Stub `PullRequest#sync` — don't use `graphql_mock` in webhook request specs

`PullRequest#sync` calls `GithubApi::Graphql.client_by_repository(repo)` which calls
`GraphQL::Client.load_schema(http)` — a live HTTP introspection query. Even with `graphql_mock`
stubs in the `before` block, WebMock body-matching on the introspection query body may not match
(operation names change per repository ID; the stub format is fragile).

**Correct approach for webhook tests**: stub at the model level:

```ruby
before do
  allow_any_instance_of(PullRequest).to receive(:sync).and_return(nil)
end
```

For tests that need to verify `merged_at` was updated, override per-example:
```ruby
allow_any_instance_of(PullRequest).to receive(:sync) do |pr|
  pr.update_columns(merged_at: Time.current, mergeable_state: 'MERGED')
end
```

The GraphQL sync logic itself is tested in `spec/lib/github_api/graphql_spec.rb`.

### `PullRequest#repository` is resolved dynamically from URL — factory URL must match

`PullRequest#repository` does: `Repository::Github.find_by(url: "https://github.com/#{owner}/#{name}.git")`

For a PR with URL `https://github.com/company/repo/pull/1`, the repository must have
URL `https://github.com/company/repo.git`. The default factory sequence produces
`https://github.com/company/repo1.git` (with number suffix) which does NOT match.

Always create the repository with an explicit URL:
```ruby
let(:repository) { create(:github_repository, project: project, url: 'https://github.com/company/repo.git') }
```

### `form_with` does not add `id` attributes to inputs (Rails 5.1+ default)

Capybara's `fill_in 'Label Text'` relies on label→for→input id chain. When `form_with` is used
without `id: true`, inputs have `name` but no `id`. Label-based lookup fails.

Use field name lookup instead:
```ruby
fill_in 'project_threshold[completion_ok]', with: '90'
expect(page).to have_field('project_threshold[completion_ok]')
find('[type=submit]').click  # instead of click_button 'Save' (avoids locale issues)
```

### `project_version_path` does not exist in Redmine 6.0-stable

Redmine 6.0 routes for versions: `project_versions_path` (index), `new_project_version_path`,
`close_completed_project_versions_path` — **no show route** (`project_version_path`).

Any controller redirect to `project_version_path(@project, @version)` will raise `NoMethodError`.
Use `project_versions_path(@project)` instead.

---

## What's NOT Tested Yet

- OAuth flow (requires real GitHub OAuth app)
- `DataIntegrityWarning` and `MetricSnapshot` display
- Trend analysis table (requires multiple versions with closed issues)
- `SystemSyncStatus` display in the dashboard
- `WorkflowRunHandler`, `DeploymentStatusHandler`, `ReleaseHandler` webhook events
