# Changelog

All notable changes to Recording Studio Identity are documented here.

The format is based on Keep a Changelog, and this project uses Semantic Versioning.

Repository: https://github.com/bowerbird-app/RecordingStudio_identity

## [0.7.1] - 2026-11-18

### Added

- `RecordingStudio::Capabilities::Identities.to` accepts `trashable:`. It defaults to `true`. `trashable: false` stops identities on that parent from being trashed. Edit and show hide the trash button. The identity delete route flashes and does not trash. `recording_studio_trashable_trash!` raises `RecordingStudioIdentity::NotTrashable`. `can?(:trash)` is false. Editing still works. Images stay trashable. The identity JSON resource still does not expose trash. `POST .../actions/trashable_trash` and `DELETE /identities/:id` are refused.

### Upgrade notes

Pin `v0.7.1`. There is no identity migration. Leave `trashable:` unset to keep today's behaviour. Opt out per parent with `Identities.to(allow: :one, trashable: false)`. This is not a global config flag. Any other value raises `ConfigurationError`. Restore still works for an identity that is already in the trash. The dummy Workspace uses `trashable: false`. Agency and Project stay trashable.

## [0.7.0] - 2026-11-18

### Added

- Identity create and edit accept `return_to`. A safe path is carried from the category screen to the details form, and from the edit form, as a hidden field. After a successful create or update the screen redirects there. Cancel and back use it too.
- `config.allow_return_to` is an optional callable. It receives a path that already passed the same-host check and can reject it. Leave it unset to allow every safe path.

### Upgrade notes

Pin `v0.7.0`. There is no identity migration. Hosts that do not pass `return_to` keep the redirect to the identity page. A safe path starts with one `/`. Protocol-relative paths, schemes, backslashes, and control characters are ignored. `config.allow_return_to` can narrow that set. It cannot make an unsafe value into a redirect.

## [0.6.2] - 2026-11-18

### Changed

- The `create_upload` title is `Upload identity picture`. The summary is `Prepare an upload for this identity's picture.` MCP 0.36.3 and later show a documented action title as written, so the shown title is `Upload identity picture`. The action name stays `create_upload`.

### Upgrade notes

Pin `v0.6.2`. There is no identity migration. The route, inputs, and action name stay the same. Hosts that show MCP or OpenAPI docs pick up the new title and summary. No host code change is required.

## [0.6.1] - 2026-11-17

### Added

- Expose Attachable `create_upload` on identities. `POST /identities/:id/actions/create_upload` returns `signed_blob_id`, `upload.url`, and `upload.headers`. PUT the file to that URL, then call `identity_set_image`. The MCP title is `Identity - Create upload`.

### Changed

- Rewrite the OpenAPI and MCP copy for `identity_set_image` and `identity_remove_image`. The action title is `Set image` or `Remove image`. MCP prefixes the recordable label, so the shown title is `Identity - Set image` or `Identity - Remove image`.
- Describe `signed_blob_id`, the identity recording id, the returned identity JSON, edit access, trash, the one-image limit, `image/*`, and the 10 MB limit. Set image says to call `create_upload` on this identity, PUT the bytes, then pass `signed_blob_id`.
- Group Identity API operations under the Identity docs tag.

### Upgrade notes

Pin `v0.6.1`. There is no identity migration. `identity_set_image` still takes `signed_blob_id`. Identities now also expose `create_upload`. `attach` and `import_attachment` stay off. Hosts that show MCP or OpenAPI docs pick up the new tool, titles, descriptions, and the Identity tag. No host code change is required.

## [0.6.0] - 2026-11-15

### Changed

- Require Recording Studio `>= 7.0`, `< 8.0`.
- An identity image is a single child under the identity (`recording_studio_identity.image`). A parent that allows one identity registers that parent (`recording_studio_identity.identity.<Type>`). Recording Studio locks the parent and raises `RecordingStudio::SlotTaken`. A second identity is still `IdentityAlreadyExists`. A second image is still `ImageRejected` with "An identity can have only one image". Replacing an image revises the current image recording. The image stays trashable so remove, and trash of the identity, still trash the attachment.
- Create roots with `RecordingStudio.create_root_recording!`. `root_recording_for` only finds an existing root and returns nil when there is none.
- Development and dummy apps pin Recording Studio `v7.0.0`, Accessible `v0.43.1`, Attachable `v0.26.0`, Trashable `v0.16.1`, Admin `v2.16.0`, API `v0.23.4`, Logs `v0.7.5`, Moveable `v4.2.0`, Root Switchable `v0.15.1`, and FlatPack `v0.1.376`. Metrics `v0.8.0`, Cache `v0.6.3`, and Icons `v0.2.1` stay on their current releases.
- The dummy no longer defines `Recording.recording_studio_trashable_kept_sql`. Accessible 0.43, API 0.23.4, and Admin 2.16 do not call it.

### Upgrade notes

Pin `v0.6.0`. There is no identity migration. The image and a one-identity parent are pairwise slots, so they are not in the `recording_studio:single_child_index` partial index. Do not run that generator for this gem.

Hosts need Recording Studio `>= 7.0`, `< 8.0`. Create roots with `RecordingStudio.create_root_recording!(recordable, actor:)`. `root_recording_for` returns nil until that create. `config.authorize_write` must allow the create when `root_recording` is nil.

Companions that resolve with core 7 here: Accessible `v0.43.1`, Trashable `v0.16.1`, Attachable `v0.26.0`, API `v0.23.4`, and Admin `v2.16.0`. Attachable 0.26 needs FlatPack `>= 0.1.371`. This repo pins FlatPack `v0.1.376`.

Drop a host copy of the `recording_studio_trashable_kept_sql` alias if it only existed for API 0.23 or Admin 2.13. Those releases no longer call it.

A second image is rejected. Replace the file on the existing image recording. Trashing an image does not free the slot. `:one` still raises `IdentityAlreadyExists` when the slot is taken, including when the occupant is trashed.

Identity enables Trashable on the attachment type so remove and cascade can trash the image. That is `RecordingStudio.enable_capability`, not an include of Trashable on every reload.

## [0.5.2] - 2026-11-14

### Changed

- Live identity lists, lookups, image reads, and the identity screens use `RecordingStudio::Recording.kept`. `include_trashed: true` still reads the unfiltered relation, so a trashed identity keeps a `:one` slot until it is purged.
- Require Recording Studio `>= 6.14.0`, Trashable `>= 0.16.0`, and Accessible `>= 0.42.0`. Development Gemfiles pin `v6.14.0`, `v0.16.0`, and `v0.42.0`.

### Upgrade notes

Pin `v0.5.2`. There is no identity migration. Hosts need Recording Studio `>= 6.14.0`, Trashable `>= 0.16.0`, and Accessible `>= 0.42.0`. Follow Recording Studio 6.14 for the events `root_recording_id` column. The dummy app copies that migration so it can write events on 6.14.

`Recording.kept` applies every registered recording filter, not only trash. Restore, the in-trash screen, and the edit guard treat a recording that is missing from `Recording.kept` as trashed. Core has no loaded-record predicate, so those checks ask `Recording.kept.exists?`.

API 0.23 and Admin 2.13 still call `Recording.recording_studio_trashable_kept_sql`, which Trashable 0.16 removed. Accessible 0.42 does not. The dummy defines that method as `RecordingStudio.kept_sql` until API and Admin move. A host on those API or Admin releases needs the same alias.

## [0.5.1] - 2026-11-14

### Upgrade notes

The category screen renders FlatPack radio cards. That needs FlatPack `>= 0.1.362` (GitHub tag `v0.1.362`, not a RubyGems release). Pin that tag in the host Gemfile. Hosts that scan FlatPack components for Tailwind need one CSS rebuild so the card grid and selected-card classes are present. Do not rerun the FlatPack install generator. There is no identity migration.

Radios stay `name="kind"`, required, and unselected until someone picks a category. An unknown `kind` still shows the danger alert and does not check a radio. The page heading, back link, and full-width Continue button are unchanged. The group legend repeats the creation title for screen readers.

### Changed

- Replace the hand-rolled category radios with `FlatPack::RadioGroup::Component` (`variant: :cards`, `align: :start`, `columns: 2`, `hide_label: true`).
- Pin development and dummy FlatPack to `v0.1.362` and raise the gemspec floor to `>= 0.1.362`.

## [0.5.0] - 2026-11-12

### Added

- Identity index, show, create, and update on Recording Studio API, with custom handlers that call `RecordingStudioIdentity.identities`, `.find`, `.create`, and `.update`.
- `identity_set_image` and `identity_remove_image` API capability actions (`:edit`), the same writes as the identity screens. They sit on Identity's `:identity_image` capability, not attachable, so other Attachable types do not get them.
- Dummy mounts Recording Studio API so hosts and MCP adapters can use the same Accessible-gated surface.

### Upgrade notes

Pin `v0.5.0`. There is no identity migration. Hosts that already have Recording Studio API get identities when this gem loads. Install and mount API (and MCP, if you use it) as those gems document. Trash, restore, attach, import image, and hard destroy stay off this resource. Index paginates. `kind` is required on create and cannot change on update. Image writes use `identity_set_image` and `identity_remove_image`. Recording Studio API 0.21.3 requires a member capability, so those actions use `:identity_image` on Identity. Identity still enables `:attachable` for the image files.

Dummy and development apps pin Recording Studio API `v0.21.3`, with Admin `v2.12.0`, Logs `v0.7.3`, Moveable `v4.1.0`, and Icons `v0.2.0` so Bundler can resolve and boot the API gem.

## [0.4.2] - 2026-11-05

### Upgrade notes

Recording Studio Identity 0.4.2 keeps the gemspec floors at Recording Studio `>= 6.1.0`, Accessible `>= 0.22.0`, Attachable `>= 0.22.0`, Trashable `>= 0.12.0`, and FlatPack `>= 0.1.320`. Public `RecordingStudio::Hooks` on configuration is unchanged. Hosts should refresh development pins to Recording Studio `v6.3.0`, FlatPack `v0.1.341`, Accessible `v0.24.1`, Trashable `v0.12.2`, Metrics `v0.7.2`, Cache `v0.6.2`, and Root Switchable `v0.11.5`, then lock Rails `8.1.4.1` with rack `>= 3.2.8`, nokogiri `>= 1.19.5`, loofah `>= 2.25.3`, and rails-html-sanitizer `>= 1.7.2`. Accessible `0.24.1` and Root Switchable `0.11.5` already allow those floors, so the dummy Gemfile no longer widens gemspecs at Bundler load.

`config.layout` is still registered through `Layout.accept`. Leave it `nil` for Recording Studio's default layout. Identity cards render FlatPack `Card` (`background`, `border`, `shadow`). Save and Cancel on add and edit sit in a FlatPack `ButtonGroup` with `collapse: :menu`. Category radio tiles on choose are unchanged.

Dummy Sign out uses FlatPack Button `href:` so the control is a Turbo DELETE link, not a dead `<button url>`. Engine `TrashButton url:` is unchanged.

The leftover template documentation directory and `MIGRATION_NOTES.md` are gone. They were leftover template files, not product docs.

### Changed

- Pin the dummy and development Gemfiles to Recording Studio 6.3.0 and the current Accessible, Trashable, Metrics, Cache, Root Switchable, and FlatPack tags.
- Lock Rails 8.1.4.1 and the audited rack, nokogiri, loofah, and rails-html-sanitizer floors in both lockfiles.
- Render identity cards with FlatPack Card and wrap Save and Cancel in a collapsing ButtonGroup.
- Drop the Bundler gemspec-widen shim now that Accessible 0.24.1 and Root Switchable 0.11.5 resolve against Recording Studio 6.3.0 and Trashable 0.12.2.
- Remove leftover template documentation and `MIGRATION_NOTES.md`.
- Dummy Sign out uses FlatPack Button `href:` so the control is a Turbo DELETE link, not a dead `<button url>`. Engine `TrashButton url:` is unchanged.

## [0.4.1] - 2026-10-29

### Changed

- Replace leftover GemTemplate names in Copilot and agent instructions with Recording Studio Identity.
- Rename the gemspec Recording Studio pin test so the method name matches `>= 6.1.0`.

## [0.4.0] - 2026-10-27

### Upgrade notes

Recording Studio Identity 0.4.0 requires Recording Studio `>= 6.1.0`. The `< 5` cap is gone. FlatPack stays `>= 0.1.320`. Accessible is `>= 0.22.0`, Attachable is `>= 0.22.0`, and Trashable is `>= 0.12.0`. ViewComponent stays on `>= 4.14, < 5` through FlatPack. No database migration runs for 0.3.0 to 0.4.0.

`RecordingStudio::UsesDefaultLayout`, `layout "recording_studio/default_layout"`, and `recording_studio_page_nav` are gone. Set `config.layout` to `nil` for the Recording Studio default layout, `false` for no layout, a layout name, or a callable that takes `controller:`. Controllers read that setting with `recording_studio_layout`.

Page headings are `content_for :title` and `content_for :subtitle`. The default layout renders one page title from those slots. Do not also render `FlatPack::PageTitle::Component` for the same heading. Back and close use `flat_pack_page_nav`. The index add button stays a default-style button in `recording_studio_page_nav_right`, not the page registry.

The add and edit form is a two-column grid from the `md` breakpoint. The image, name, website, about, Save, and Cancel sit in column 1. The image uploader has no visible Image label. Its file input keeps an accessible name from the image alt text, or from FlatPack's choose label when the image is new. Cancel is a default-style button. Edit puts delete in the layout top-right slot as FlatPack's trash button, with `expand: :left`.

Accessible 0.22.0 still declares Trashable `~> 0.10`, and root switchable 0.10.0, metrics 0.6.1, and cache 0.5.1 still declare Recording Studio 4.x. This repository widens those gemspec floors before Bundler resolves, so the dummy app can run Recording Studio 6.1.0 with Trashable 0.12.0. A host Gemfile that pins the same tags needs the same widen, or newer tags that already allow these versions.

### Changed

- Depend on Recording Studio 6.1.0 and the current Accessible, Attachable, and Trashable releases.
- Resolve the page layout from `config.layout` instead of a hardcoded default layout.
- Render one heading from `content_for :title` and `content_for :subtitle`. Back and close use `flat_pack_page_nav`. The add button stays in the layout top-right slot.
- Place the image, name, website, about, Save, and Cancel in column 1 of the add and edit form. Omit the visible Image label. Use a default-style Cancel button.
- Move edit's delete action to the layout top-right slot as FlatPack's trash button, expanding left.

## [0.3.0] - 2026-10-26

### Upgrade notes

This version replaces the addon template with Recording Studio Identity. Hosts that mounted the template should mount `RecordingStudioIdentity::Engine` and delete the example capability. Install the identity migration and Active Storage before uploading images. Existing template page tables are not reused.

Add and edit screens list name, website, description, then image. The image control is FlatPack's image input, which needs FlatPack `>= 0.1.320` and Recording Studio `>= 4.7.1` (the default layout that matches this page nav). Hosts that scan FlatPack for Tailwind need one CSS rebuild so the image input classes are present. Choosing a file still direct-uploads a signed blob, and Save stores it. Clearing a saved image and saving removes it. `DELETE` on the image path still removes it immediately. FlatPack cards no longer take `style:`. A host that mounts root switchable with this FlatPack needs root switchable `0.10.0` and metrics `>= 0.3.1`, and a Tailwind source for that gem's components.

Default field labels are Name, About, Image, and Website. A host `fields` map still replaces any of those labels.

`config.label` and `config.plural_label` rename the identity on screen. Leave them unset and the screens still say Identity and Identities. Set both when a host wants another name. The details and edit form is two columns from the `md` breakpoint, with the image in the first column and name, website, and about in the second. Narrow screens stack the image above the fields.

The category screen shows the creation title and a full-width Continue button with space above the cards. It does not render `creation.description`. That value remains on `config.creation` for hosts that read it. The index add action is a default-style button in the layout top-right slot (`recording_studio_page_nav_right`), shown only when create is allowed.

Moving Recording Studio Company records onto identities is a separate migration. It is not run by this release. It has to copy recording references, revision history, images, and parent relationships, and Press Kits has to be pointed at the new recordings.

### Changed

- Add and edit forms show name, website, description, then FlatPack's image input. Choosing a file direct-uploads a signed blob that Save stores. Clearing a saved image and saving removes it. From the `md` breakpoint those screens use two columns. The image is the first column. Name, website, and about are the second.
- Default and demo field labels are Name, About, Image, and Website.
- Screen headings, buttons, empty states, flashes, and trash and restore copy use `config.label` and `config.plural_label`. The defaults remain Identity and Identities.
- The category screen omits `creation.description`. Continue spans the form, with space above the category cards.
- The index add action is a default-style button in the layout top-right slot.

### Added

- `RecordingStudioIdentity::Identity`, a non-root recordable with name, kind, description, website URL, and one optional image.
- Parent capability `RecordingStudio::Capabilities::Identities.to(allow: :one)` and `allow: :many`, including the trashed-slot rule for `:one`.
- `RecordingStudioIdentity.configure` for categories and creation copy.
- Public create, read, update, image, and authorization methods that return recordings.
- FlatPack creation and management screens, plus image, card, and display-name helpers.
- Dummy examples for one identity, many identities, a nested project, and configurable field labels.

## [0.2.10] and earlier

Earlier tags belonged to the addon template this repository was renamed from. See the git history of that template for those notes.
