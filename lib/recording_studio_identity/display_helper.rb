# frozen_string_literal: true

module RecordingStudioIdentity
  module DisplayHelper
    def recording_studio_identity_image(identity, size: :md, shape: :rounded)
      name = RecordingStudioIdentity.display_name(identity)
      image = RecordingStudioIdentity.image(identity)
      variant = %i[xs sm md].include?(size.to_sym) ? :square_small : :square_med
      src = image && authorized_attachment_preview_path(image, variant)
      alt = I18n.t("recording_studio.identity.image.alt", name: name, default: "#{name} image")

      render FlatPack::Avatar::Component.new(src: src, alt: alt, name: name, size: size, shape: shape)
    end

    def recording_studio_identity_card(identity, description: true, website: true)
      render partial: "recording_studio_identity/identities/card",
             locals: { identity: identity, show_description: description, show_website: website }
    end

    def recording_studio_identity_display_name(identity)
      RecordingStudioIdentity.display_name(identity)
    end
  end
end
