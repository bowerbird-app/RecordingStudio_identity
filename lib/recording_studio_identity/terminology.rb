# frozen_string_literal: true

module RecordingStudioIdentity
  class Terminology
    LABEL_KEY = "recording_studio.identity.terminology.label"
    PLURAL_KEY = "recording_studio.identity.terminology.plural_label"

    def initialize(label: nil, plural_label: nil)
      @label = presence(label)
      @plural_label = presence(plural_label)
    end

    def label
      @label || I18n.t(LABEL_KEY, default: "Identity")
    end

    def plural_label
      @plural_label || I18n.t(PLURAL_KEY, default: "Identities")
    end

    def term
      in_sentence(label)
    end

    def plural
      in_sentence(plural_label)
    end

    def article
      vowel?(term) ? "an" : "a"
    end

    def interpolations
      {
        label: label,
        plural_label: plural_label,
        term: term,
        plural: plural,
        article: article,
        Article: article.capitalize
      }
    end

    private

    def presence(value)
      text = value.to_s.strip
      text unless text.empty?
    end

    def in_sentence(text)
      text.sub(/\A[[:upper:]]/, &:downcase)
    end

    def vowel?(text)
      text.lstrip.match?(/\A[aeiou]/i)
    end
  end
end
