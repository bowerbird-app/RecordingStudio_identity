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

Optional: install Recording Studio API so identity index, show, create, update, set_image, and remove_image are available over JSON and MCP.

To use the engine:
1. Start your Rails server
2. Visit http://localhost:3000/recording_studio_identity

===============================================================================
