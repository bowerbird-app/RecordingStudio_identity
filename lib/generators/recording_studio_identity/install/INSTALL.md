===============================================================================

RecordingStudioIdentity has been installed successfully!

The engine has been mounted at /recording_studio_identity in your application.

If you use Tailwind CSS:
1. Run 'bin/rails tailwindcss:build' to rebuild your CSS with RecordingStudioIdentity styles

Image upload needs Attachable and these importmap pins:

    pin "@rails/activestorage", to: "activestorage.esm.js"
    pin_all_from RecordingStudioAttachable::Engine.root.join("app/javascript/controllers/recording_studio_attachable"),
      under: "controllers/recording_studio_attachable",
      to: "controllers/recording_studio_attachable",
      preload: false

Optional: install Recording Studio API so identity index, show, create, update, identity_set_image, identity_remove_image, show_current_identity, and update_current_identity are available over JSON and MCP. Set config.current_identity_tag when those two current-root tools should sit in another docs group. The default group is Identity.

To use the engine:
1. Start your Rails server
2. Visit http://localhost:3000/recording_studio_identity

===============================================================================
