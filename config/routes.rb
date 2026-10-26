# frozen_string_literal: true

RecordingStudioIdentity::Engine.routes.draw do
  resources :recordings, only: [] do
    resources :identities, only: %i[index new create]
  end

  resources :identities, only: %i[show edit update destroy] do
    member do
      post :restore
      patch :image, action: :set_image
      delete :image, action: :remove_image
    end
  end
end
