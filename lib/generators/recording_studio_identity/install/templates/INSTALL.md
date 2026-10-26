RecordingStudioIdentity install complete.

The engine is mounted at the configured mount path, /recording_studio_identity by default.

Next steps:

1. Install Attachable with `bin/rails generate recording_studio_attachable:install`. It mounts Attachable for image previews, pins its Stimulus controllers and `@rails/activestorage`, and starts Active Storage.
2. Pin direct upload in `config/importmap.rb`:

```ruby
pin "@rails/activestorage", to: "activestorage.esm.js"
pin_all_from RecordingStudioAttachable::Engine.root.join("app/javascript/controllers/recording_studio_attachable"),
  under: "controllers/recording_studio_attachable",
  to: "controllers/recording_studio_attachable",
  preload: false
```

3. Install the engine migrations with `bin/rails generate recording_studio_identity:migrations`.
4. Apply the migrations with `bin/rails db:migrate`.
5. Review `config/initializers/recording_studio_identity.rb`. Add `config/recording_studio_identity.yml` when a setting changes by environment.
6. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
7. Mount routes are added at the configured mount path. Adjust auth, layout, and current actor integration to match your host app.
8. Keep strict recordable declarations enabled and add `recording_studio_recordable(...)` to every configured recordable before running `RecordingStudio.validate_recordable_declarations!`.