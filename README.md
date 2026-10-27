# Recording Studio Identity

Recording Studio Identity stores public identities under any recording that opts in. A person, company, brand, or organisation is a `RecordingStudio::Recording`. The permanent id is that recording id. Revisions replace the `RecordingStudioIdentity::Identity` snapshot and keep the same recording.

The gem does not represent a user account, a workspace, or a login. It does not depend on Recording Studio Company, and it does not migrate Company records.

Source and changelog: `https://github.com/bowerbird-app/RecordingStudio_identity`.

## What an identity is

`RecordingStudioIdentity::Identity` is a non-root recordable.

```ruby
recording_studio_recordable label: "Identity", plural_label: "Identities", root: false
```

Parents opt in with the identities capability. The identity does not declare a fixed parent list. Recording Studio registers each parent type that calls `Identities.to`.

Fields:

| Field | Required | Limit | Notes |
| --- | --- | --- | --- |
| `name` | yes | 200 | Whitespace is collapsed to nil when blank |
| `kind` | yes | category key | Checked against configured categories on create |
| `description` | no | 5000 | Omitted from the detail page when blank |
| `website_url` | no | 2048 | HTTP or HTTPS with a host |
| image | no | 10 MB | One Attachable image |

`kind` is stored lowercase. Create rejects a kind that is not configured. Update does not accept `kind`. If a category is later removed from configuration, existing identities keep that kind and stay editable.

`website_href` returns the stored URL only when it is an HTTP or HTTPS URI with a host. The gem does not add a scheme for you.

Trashable is enabled. Duplicatable and Orderable are not.

## Parent capability

```ruby
include RecordingStudio::Capabilities::Identities.to(allow: :one)
include RecordingStudio::Capabilities::Identities.to(allow: :many)
```

`allow:` is required. Any other value raises `RecordingStudioIdentity::ConfigurationError` with the text `allow: :one or allow: :many`.

`:one` allows a single identity. A trashed identity still occupies that slot until it is purged. A second create raises `RecordingStudioIdentity::IdentityAlreadyExists`. `:many` lists every live identity in name order.

Shared roots cannot hold identities. The write path locks the root recording and then the parent, in the same order as `record!`.

## Configuration

```ruby
RecordingStudioIdentity.configure do |config|
  config.label = "Press profile"
  config.plural_label = "Press profiles"

  config.types = {
    person: {
      label: "Person",
      description: "Creators, influencers and individuals",
      icon: "user",
      fields: {
        name: "Name",
        description: "About",
        image: "Image",
        website_url: "Website"
      }
    }
  }

  config.creation = {
    title: "Who is this press profile for?",
    description: "Choose the type of press profile you'd like to create.",
    continue_label: "Continue"
  }
end
```

`config.label` and `config.plural_label` are the singular and plural names on screen. Headings, buttons, empty states, flashes, and trash and restore copy use them. Leave both unset to keep Identity and Identities. Those defaults come from `config/locales/en.yml`, so a locale can rename them too. Set both together. `label` is the heading form (`Press profile`, `+ Press profile`). Sentences lowercase the first letter (`Add press profile`, `No press profiles yet`). A word that starts with a, e, i, o, or u takes "an". Any other word takes "a".

`config.types` is a map of category key to label, description, icon, and field labels. Keys are normalized to lowercase. Duplicate normalized keys are rejected. Unknown options and unknown field names are rejected. Field labels change presentation only. Every category uses the same model. The default labels are Name, About, Image, and Website. Set `fields` to replace any of them.

Icons accept the Heroicon names used by FlatPack. `user-round`, `building-2`, and `users` are accepted as aliases.

When `config.types` is omitted, the gem uses person, company, brand, and organisation. There is no Featured In default.

`config.creation` still accepts a title, description, and continue label. Blank values fall back to `config/locales/en.yml`. Set `description` to a blank string and the config object omits it. The category screen shows the title and the continue label. It does not render the description.

## Public Ruby API

Reads do not authorize. Writes require Accessible `:edit` on the parent or identity, and `RecordingStudio.record!` still runs the host `authorize_write` hook.

```ruby
recording = RecordingStudioIdentity.create(
  parent_recording,
  actor: current_user,
  kind: "person",
  name: "Ada Lovelace",
  description: "Mathematician",
  website_url: "https://example.com",
  idempotency_key: "optional-retry-key",
  signed_blob_id: blob.signed_id
)
```

`create` returns a `RecordingStudio::Recording`. The same parent and `idempotency_key` return that recording again, including after it is trashed. A second create on a full `:one` parent raises `IdentityAlreadyExists` instead of returning the first recording.

```ruby
RecordingStudioIdentity.identity(parent_recording) # Recording or nil; raises on :many
RecordingStudioIdentity.identities(parent_recording, include_trashed: false)
RecordingStudioIdentity.find(recording_id)
RecordingStudioIdentity.update(identity_recording, actor:, name:, description:, website_url:)
```

`update` uses `revise`. The recording id stays the same. An update that does not change name, description, or website URL does not write a revision.

```ruby
RecordingStudioIdentity.categories
RecordingStudioIdentity.category("person")
RecordingStudioIdentity.category_for(identity_recording)
RecordingStudioIdentity.creation
RecordingStudioIdentity.display_name(identity_recording)
RecordingStudioIdentity.image(identity_recording)
RecordingStudioIdentity.set_image(identity_recording, signed_blob_id:, actor:)
RecordingStudioIdentity.remove_image(identity_recording, actor:)
RecordingStudioIdentity.can?(:view, recording, actor:)
```

`can?` accepts `:view`, `:create`, `:update`, `:trash`, and `:restore`.

Trash and restore use Trashable on the recording. There is no second wrapper.

```ruby
identity_recording.recording_studio_trashable_trash!(actor:)
identity_recording.recording_studio_trashable_restore!(actor:)
```

Image bytes go through Attachable (`RecordAttachmentUpload`, `ReplaceAttachmentFile`, `RemoveAttachment`). Content types must be images and the file must be at most 10 MB.

## Creation and management UI

Routes are mounted with the engine. The default path is `/recording_studio_identity`.

1. Category screen. Each configured category is a card with icon, label, and description. The heading and continue label come from `config.creation`. The screen does not show `creation.description`. Continue is full width, with space above it. Nothing is recorded on this step.
2. Details screen. From the `md` breakpoint the form is a two-column grid. The image, name, website, about, and the Save, Cancel, and Delete row sit in column 1. The image uploader has no visible label. The file input keeps an accessible name. Cancel is a default-style button. Field labels come from that category.

One configured category skips the category screen. Zero categories render an alert that tells the host to add a category. The details form does not offer an unrestricted kind change.

`:many` index lists live identities and an add action, plus trashed identities that can be restored. The add action is a default-style button in the layout top-right slot, and it is shown only when create is allowed. `:one` index shows the identity, or that same add action when the slot is empty. A trashed identity offers restore and still occupies the slot. Show hides blank description and website. Edit uses that same column and the category labels. The image control is FlatPack's image input. Choosing a file direct-uploads a signed blob, and Save stores it with the identity. Clearing a saved image and saving removes it. `DELETE` on the image path still removes it immediately. Delete moves the identity to the trash. The visible name of an identity follows `config.label` and `config.plural_label`.

## Display components

These helpers are for other gems. They do not generate host routes.

```erb
<%= recording_studio_identity_image(identity, size: :lg, shape: :circle) %>
<%= recording_studio_identity_card(identity, description: true, website: true) %>
<%= recording_studio_identity_display_name(identity) %>
```

Sizes follow FlatPack Avatar (`xs`, `sm`, `md`, `lg`, `xl`, `2xl`). Shapes are `circle`, `rounded`, and `square`. A missing image falls back to initials. The card shows the image, name, and the optional description and website.

## Authorization and other capabilities

Accessible decides who can view and edit. Create is authorized on the parent. The identity recordable does not enable Accessible itself. Access walks the parent chain to the root.

Attachable stores the optional image. Trashable cascades, so the image is trashed and restored with the identity.

State changes go through `RecordingStudio.record!` (which logs the created event) and `revise`. Retries pass `idempotency_key`. The gem uses `RecordingStudio::Hooks` and Attachable services that extend `RecordingStudio::Services::BaseService`. It does not copy those classes.

## Boundaries

An identity is not a user and not a workspace. Do not store `workspace_id` or `owner_id` on the snapshot. Store the recording id.

The gem does not read or write Company records. A future move from Company to Identity has to copy recording references, revision history, images, and parent relationships, and it has to retarget Press Kits. That migration is not included and does not run on install.

## Installation

Pin the gem and its runtime dependencies, then install.

```ruby
gem "recording_studio_identity", github: "bowerbird-app/RecordingStudio_identity"
```

Runtime dependencies are Rails `~> 8.1.0`, Recording Studio `>= 6.1.0`, Accessible `>= 0.22.0`, Attachable `>= 0.22.0`, Trashable `>= 0.12.0`, and FlatPack `>= 0.1.320`. Recording Studio 6.1 supplies the default layout. `config.layout` chooses another layout name, `false`, or a callable that takes `controller:`. Page headings use `content_for :title` and `content_for :subtitle`. Back and close use `flat_pack_page_nav`.

```bash
bin/rails generate recording_studio_identity:install
bin/rails generate recording_studio_identity:migrations
bin/rails db:migrate
bin/rails active_storage:install
bin/rails db:migrate
```

`recording_studio_identity:install` mounts the engine, adds an initializer, and adds Tailwind sources for the engine and FlatPack. Copy the identity migration into the host. Active Storage tables are required before an image can be uploaded.

Image upload uses Attachable's direct-upload controller. Pin it in the host `config/importmap.rb`:

```ruby
pin "@rails/activestorage", to: "activestorage.esm.js"
pin_all_from RecordingStudioAttachable::Engine.root.join("app/javascript/controllers/recording_studio_attachable"),
  under: "controllers/recording_studio_attachable",
  to: "controllers/recording_studio_attachable",
  preload: false
```

Enable the capability on each parent model, root or not.

```ruby
class Workspace < ApplicationRecord
  recording_studio_recordable label: "Workspace", root: true
  include RecordingStudio::Capabilities::Identities.to(allow: :one)
end
```

Register your own recordable types in the Recording Studio initializer. The engine registers `RecordingStudioIdentity::Identity`.

## Dummy application

The dummy app at `test/dummy` signs in with `admin@admin.com` / `Password`.

- Workspace `Studio Workspace` holds one identity.
- Agency `Harbour Agency` holds many identities.
- Project `Harbour fit-out` sits under the studio workspace and holds its own identities.
- The agency create screen uses the configured title and continue label, and the category field labels. `creation.description` stays on the config object and is not shown on that screen.

## Tests

```bash
bundle exec rake test:rename_verification
bundle exec rake test:all
bundle exec rubocop
bin/bundler-audit
bin/brakeman
bin/importmap audit
```

`rake test:all` runs the gem suite and the dummy app. Identity behaviour is covered against the real Recording Studio, Accessible, Attachable, and Trashable gems.
