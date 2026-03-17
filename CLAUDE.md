# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Development (runs Rails server + Tailwind watcher)
bin/dev

# Run all tests
bin/rails test

# Run a single test file
bin/rails test test/models/post_test.rb

# Run a single test by line number
bin/rails test test/models/post_test.rb:42

# Database
bin/rails db:migrate
bin/rails db:seed

# Deploy to production
kamal deploy

# Create admin user after deploy
kamal console
# then: User.create!(email: 'admin@example.com', password: 'password')
```

## Architecture

### Authentication
Rails 8 built-in authentication (`has_secure_password`). The `Authentication` concern (`app/controllers/concerns/authentication.rb`) is included in `ApplicationController` and provides `current_user` / `require_authentication`. The admin namespace (`Admin::ApplicationController`) inherits from this and enforces login.

### Post lifecycle
Posts have `draft`/`published` statuses. On save, `Post` model callbacks:
1. `attach_content_images` — scans Markdown content for Active Storage blob URLs and attaches them to the post
2. `clean_unused_images` — purges blobs no longer referenced in content
3. `schedule_image_processing` — enqueues `ProcessPostImagesJob` when a post is published

`ProcessPostImagesJob` resizes images exceeding 1024×1024 in-place by re-uploading to the same blob key.

### Markdown rendering
`MarkdownRenderable` concern (included in `Post` model) uses Redcarpet + Rouge for syntax-highlighted Markdown. Call `post.rendered_content` to get HTML.

### Slugs
`friendly_id` with `ruby-pinyin` converts Chinese titles to pinyin slugs automatically. Posts also support a `custom_slug` field (lowercase letters, numbers, hyphens only). Always use `.friendly.find(params[:id])` in controllers.

### Image uploads (admin editor)
`POST /admin/posts/upload_image` accepts a multipart image, creates an unattached Active Storage blob, and returns a Markdown snippet. The blob is formally attached to the post when the post is saved (via `attach_content_images`).

### Settings
Key-value store in `settings` table. Access via `Setting.get('key')` / `Setting.set('key', value)`. Current keys: `site_name`, `post_signature`, `icp_number`.

### Background jobs
Solid Queue runs inside Puma (configured via `SOLID_QUEUE_IN_PUMA=true`). Job admin UI at `/admin/jobs` (MissionControl::Jobs).

### Deployment
Kamal 2 deploys a Docker image to a single server (`8.134.169.142`), hosted at `www.3qruok.com`. The CI workflow on the `deploy` branch triggers `kamal deploy` automatically. SQLite data and Active Storage files persist via named Docker volumes (`atpking_blog_storage`, `atpking_blog_uploads`).
