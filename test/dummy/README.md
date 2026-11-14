# Dummy App

This Rails app hosts RecordingStudioIdentity so identity screens can run inside a real Recording Studio application.

## What It Covers

- Devise authentication with a seeded admin user
- `Current.actor` wiring for Recording Studio events
- A workspace that holds one press profile, an agency that holds many, and a project nested under a workspace. The dummy initializer names them press profiles and asks "Who is this press profile for?" on the category screen.
- Recording Studio default layout, FlatPack assets, and Tailwind source scanning
- GitHub pins for Recording Studio `v6.7.0`, Accessible `v0.32.0`, Attachable `v0.23.0`, Trashable `v0.14.0`, Metrics `v0.8.0`, Cache `v0.6.3`, Root Switchable `v0.15.0`, FlatPack `v0.1.362`, and Recording Studio API `v0.23.0` (with Admin `v2.13.0`, Logs `v0.7.4`, Moveable `v4.1.1`, and Icons `v0.2.1`)
- Mounted `RecordingStudio::Engine`, `RecordingStudioIdentity::Engine`, and Recording Studio API at `/recording_studio_api`
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
