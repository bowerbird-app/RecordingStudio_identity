# Migration notes

Recording Studio Identity `0.4.0` is the layout upgrade from `0.3.0`. It is strictly newer than `0.3.0` and template tag `0.2.10`.

## 0.3.0 to 0.4.0

No database migration is required. Do not run a new identity generator for this bump. Existing `recording_studio_identities` rows stay as they are.

1. Require Recording Studio `>= 6.1.0`. Remove any `< 5` cap. Keep FlatPack `>= 0.1.320`. Move Accessible to `>= 0.22.0`, Attachable to `>= 0.22.0`, and Trashable to `>= 0.12.0`.
2. Delete `include RecordingStudio::UsesDefaultLayout` and `layout "recording_studio/default_layout"`. Call `recording_studio_layout { RecordingStudioIdentity.configuration.layout }` from the engine controller, or `recording_studio_layout` from a host controller that should use the Recording Studio default.
3. Set `config.layout` only when the host wants something other than the default. `nil` selects `recording_studio/default_layout`. `false` renders no layout. A String is a layout name. A callable must take `controller:` and return a String, `nil`, or `false`.
4. Replace `recording_studio_page_nav` with `content_for :title`, optional `content_for :subtitle`, and `flat_pack_page_nav` for back and close. Remove the duplicate `FlatPack::PageTitle::Component` on pages that use the default layout. Keep the index add button in `recording_studio_page_nav_right`.
5. Rebuild Tailwind so the 6.1 layout and FlatPack page nav classes are in the host CSS.

Accessible `0.22.0` still caps Trashable at `~> 0.10`. Root switchable `0.10.0`, metrics `0.6.1`, and cache `0.5.1` still cap Recording Studio at 4.x. Those tags do not resolve next to Recording Studio 6.1.0 and Trashable 0.12.0 until the gemspec floors are widened at Bundler load, which this repository does in `test/support/widen_recording_studio_requirement.rb`.

## Host install

1. Add `recording_studio_identity` and keep Recording Studio `>= 6.1.0`, Accessible `>= 0.22.0`, Attachable `>= 0.22.0`, Trashable `>= 0.12.0`, and FlatPack `>= 0.1.320`. Rebuild Tailwind after the FlatPack bump so the image input classes (`h-20`, `w-36`, the overlay scrim, and the avatar shape radii) are in the host CSS. The image input controller loads from the existing FlatPack controllers pin. FlatPack cards no longer take `style:`; use `background:`, `border:`, and `shadow:`.
2. Run `bin/rails generate recording_studio_identity:install`.
3. Run `bin/rails generate recording_studio_identity:migrations` and migrate. The identity table is `recording_studio_identities` (uuid id, `name`, `kind`, `description`, `website_url`, `created_at`). The migration is reversible.
4. Install Active Storage and migrate before image upload. The image is an Attachable child recording, not a column on the identity.
5. Include `RecordingStudio::Capabilities::Identities.to(allow: :one)` or `allow: :many` on each parent. `allow:` is mandatory.
6. Configure `config.types` and `config.creation` if the defaults are not the ones you want. Set `config.label` and `config.plural_label` together when the screens should say something other than Identity and Identities. Leave `config.layout` unset to use the Recording Studio default layout. The category screen shows the creation title and continue label. It does not render `creation.description`. The index add button sits in the layout top-right slot. From the `md` breakpoint the add and edit form is a two-column grid, and the image, name, website, about, Save, and Cancel sit in column 1. The image uploader has no visible Image label. Cancel is a default-style button. Edit's delete action is FlatPack's trash button in the layout top-right slot, expanding left.

The engine registers the identity recordable. Do not add a `workspace_id` or `owner_id`. Store `RecordingStudio::Recording` ids.

## What this release does not migrate

Company records are not copied. A later Company to Identity migration has to do all of the following, and it must be explicit:

- Create an identity recording for each company recording that should move.
- Preserve the recording id only when callers can keep using it. Otherwise record the old id and the new id together.
- Copy revision history onto the identity recording.
- Copy the company image onto the identity image attachment.
- Recreate the parent relationship under the recording that should hold the identity.
- Update Press Kits, and any other gem that stores a company recording id, to the identity recording id.

None of that runs on `db:migrate` for this gem. Press Kits is unchanged.

## Template hosts

Remove the example capability and any mount of the old template engine. The template pages migration is not part of this gem. Dummy credentials still use the shared encrypted file. Do not commit `master.key`.
