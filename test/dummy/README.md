# Dummy App

This Rails app hosts RecordingStudioIdentity so identity screens can run inside a real Recording Studio application.

## What It Covers

- Devise authentication with a seeded admin user
- `Current.actor` wiring for Recording Studio events
- A workspace that holds one press profile, an agency that holds many, and a project nested under a workspace. The workspace opts out with `trashable: false`, so that press profile cannot be trashed. Agency and project press profiles still can. Images can still be removed. The dummy initializer names them press profiles and asks "Who is this press profile for?" on the category screen.
- Recording Studio default layout, FlatPack assets, and Tailwind source scanning. Pages use Flatpack's rounded theme with `<html data-theme="rounded">`.
- Create and edit accept `return_to` and send a safe relative path back to the host page.
- GitHub pins for Recording Studio `v7.8.0` (`~> 7.8`), Accessible `v0.58.0` (`~> 0.58`), Attachable `v0.34.0` (`~> 0.34`), Trashable `v1.3.0` (`~> 1.3`), Metrics `v0.10.0` (`~> 0.10`), Cache `v0.8.0` (`~> 0.8`), Root Switchable `v0.17.0` (`~> 0.17`), FlatPack `v0.2.0` (`~> 0.2`), and Recording Studio API `v1.21.3` (`~> 1.21`) (with Admin `v2.20.0` (`~> 2.20`), Logs `v0.9.0` (`~> 0.9`), Moveable `v6.1.0` (`~> 6.1`), Icons `v0.5.0` (`~> 0.5`), MCP `v0.45.2`, Oauth `v0.26.1`, and Site Settings `v0.7.0`)
- Mounted `RecordingStudio::Engine`, `RecordingStudioIdentity::Engine`, Recording Studio API at `/recording_studio_api`, Oauth at `/recording_studio_oauth`, and MCP at `/recording_studio_mcp`. Dummy `recordable_types` include `RecordingStudioSiteSettings::SiteSetting` so MCP can boot.
- Dummy docs for install, configuration, and the public API

## Quick Start

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Run the commands above from the dummy app directory, not the repository root.

Then open the app and sign in with:

- Email: `admin@admin.com`
- Password: `Password`

## Useful Routes

- `/` - identity examples for one parent, many parents, a nested parent, and creation text
- `/recording_studio` - redirects to `/` while the mounted Recording Studio engine stays available under that prefix for non-root routes
- `/recording_studio_identity` - identity screens
- `/recording_studio_api/api/v1/identities` - JSON identity resource (pass `parent_id` to list or create)
- `/users/sign_in` - Devise sign-in page
- `/docs/install`, `/docs/config`, `/docs/recordable_types`, `/docs/recordings_tree`, `/docs/gem_views`, `/docs/methods` - dummy docs for this gem
- `/up` - Rails health check

## Why This App Exists

Use this app to exercise identity creation, cardinality, trash, and restore before shipping a host change. Authenticated pages use Recording Studio's shared default layout. Devise sign-in keeps `layouts/application`.

The home page stays a short set of example links. The docs pages hold install, configuration, and API notes.
