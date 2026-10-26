# Migration notes

Recording Studio Identity `0.3.0` is the first identity release. It is strictly newer than template tag `0.2.10`.

## Host install

1. Add `recording_studio_identity` and keep Recording Studio `>= 4.7.1` and `< 5`, Accessible `~> 0.18`, Attachable `~> 0.15`, Trashable `~> 0.10`, and FlatPack `>= 0.1.320`. Recording Studio 4.7.0's default layout still passes the removed page-nav keywords, so 4.7.1 is the floor. Rebuild Tailwind after the FlatPack bump so the image input classes (`h-20`, `w-36`, the overlay scrim, and the avatar shape radii) are in the host CSS. The image input controller loads from the existing FlatPack controllers pin. FlatPack cards no longer take `style:`; use `background:`, `border:`, and `shadow:`.
2. Run `bin/rails generate recording_studio_identity:install`.
3. Run `bin/rails generate recording_studio_identity:migrations` and migrate. The identity table is `recording_studio_identities` (uuid id, `name`, `kind`, `description`, `website_url`, `created_at`). The migration is reversible.
4. Install Active Storage and migrate before image upload. The image is an Attachable child recording, not a column on the identity.
5. Include `RecordingStudio::Capabilities::Identities.to(allow: :one)` or `allow: :many` on each parent. `allow:` is mandatory.
6. Configure `config.types` and `config.creation` if the defaults are not the ones you want. Set `config.label` and `config.plural_label` together when the screens should say something other than Identity and Identities. The add and edit form places the image in the first column from the `md` breakpoint.

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
