# Changelog

All notable changes to Recording Studio Identity are documented here.

The format is based on Keep a Changelog, and this project uses Semantic Versioning.

Repository: https://github.com/bowerbird-app/RecordingStudio_identity

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
