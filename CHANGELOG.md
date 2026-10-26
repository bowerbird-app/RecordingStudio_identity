# Changelog

All notable changes to Recording Studio Identity are documented here.

The format is based on Keep a Changelog, and this project uses Semantic Versioning.

Repository: https://github.com/bowerbird-app/RecordingStudio_identity

## [0.3.0] - 2026-10-26

### Upgrade notes

This version replaces the addon template with Recording Studio Identity. Hosts that mounted the template should mount `RecordingStudioIdentity::Engine` and delete the example capability. Install the identity migration and Active Storage before uploading images. Existing template page tables are not reused.

Add and edit screens list name, website, description, then image. The sentence under the image control is gone. Edit saves a new image with the identity. Remove image still deletes immediately.

Moving Recording Studio Company records onto identities is a separate migration. It is not run by this release. It has to copy recording references, revision history, images, and parent relationships, and Press Kits has to be pointed at the new recordings.

### Changed

- Add and edit forms show name, website, description, then image. The hint under the image control is gone. Edit saves a new image with the identity.

### Added

- `RecordingStudioIdentity::Identity`, a non-root recordable with name, kind, description, website URL, and one optional image.
- Parent capability `RecordingStudio::Capabilities::Identities.to(allow: :one)` and `allow: :many`, including the trashed-slot rule for `:one`.
- `RecordingStudioIdentity.configure` for categories and creation copy.
- Public create, read, update, image, and authorization methods that return recordings.
- FlatPack creation and management screens, plus image, card, and display-name helpers.
- Dummy examples for one identity, many identities, a nested project, and configurable field labels.

## [0.2.10] and earlier

Earlier tags belonged to the addon template this repository was renamed from. See the git history of that template for those notes.
