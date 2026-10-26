# frozen_string_literal: true

require "securerandom"

module RecordingStudioIdentity
  class IdentitiesController < ApplicationController
    before_action :set_parent, only: %i[index new create]
    before_action :set_identity, except: %i[index new create]

    def index
      @allowance = RecordingStudioIdentity.allowance(@parent)
      if @allowance == :many
        @trashed_identities, @identities =
          RecordingStudioIdentity.identities(@parent, include_trashed: true).partition(&:trashed_at)
      else
        @identity = RecordingStudioIdentity.identity(@parent, include_trashed: true)
      end
    rescue IdentityIntegrityError => e
      @integrity_error = e
    end

    def new
      unless identity_can?(:create, @parent)
        return redirect_to(recording_identities_path(@parent), alert: flash_cant_add)
      end

      @categories = RecordingStudioIdentity.categories
      return render(:unconfigured) if @categories.empty?

      @category = selected_category
      if @category.nil?
        @unknown_kind = string_param(:kind).present?
        return render(:choose)
      end

      @record = Identity.new(kind: @category.key)
      @idempotency_key = SecureRandom.uuid
      render :details
    end

    def create
      identity = RecordingStudioIdentity.create(
        @parent,
        actor: current_identity_actor,
        idempotency_key: string_param(:idempotency_key),
        signed_blob_id: submitted_image_blob_id,
        **identity_params
      )
      redirect_to identity_path(identity), notice: flash_was_added(identity), status: :see_other
    rescue Invalid => e
      @record = e.record
      @categories = RecordingStudioIdentity.categories
      @category = RecordingStudioIdentity.category(@record.kind) || @categories.first
      @idempotency_key = string_param(:idempotency_key) || SecureRandom.uuid
      render :details, status: :unprocessable_content
    rescue IdentityAlreadyExists, IdentityIntegrityError => e
      redirect_to recording_identities_path(@parent), alert: user_message(e.message), status: :see_other
    end

    def show; end

    def edit
      raise Trashed.new(identity: @identity) if @identity.trashed_at
      unless identity_can?(:update, @identity)
        return redirect_to(identity_path(@identity), alert: flash_cant_edit(@identity))
      end

      @record = @identity.recordable
      @category = RecordingStudioIdentity.category_for(@identity)
    end

    def update
      identity = RecordingStudioIdentity.update(@identity, actor: current_identity_actor, **update_params)
      if (blob_id = submitted_image_blob_id)
        RecordingStudioIdentity.set_image(identity, signed_blob_id: blob_id, actor: current_identity_actor)
      elsif remove_submitted_image?
        RecordingStudioIdentity.remove_image(identity, actor: current_identity_actor)
      end
      redirect_to identity_path(identity), notice: flash_was_saved(identity), status: :see_other
    rescue Invalid => e
      @record = e.record
      @category = RecordingStudioIdentity.category_for(@identity)
      render :edit, status: :unprocessable_content
    rescue ImageRejected => e
      redirect_to edit_identity_path(@identity), alert: user_message(e.message), status: :see_other
    end

    def destroy
      unless @identity.trashed_at
        authorize_identity!(:trash, @identity)
        @identity.recording_studio_trashable_trash!(actor: current_identity_actor)
      end
      redirect_to recording_identities_path(@identity.parent_recording_id),
                  notice: flash_in_trash(@identity), status: :see_other
    end

    def restore
      if @identity.trashed_at
        authorize_identity!(:restore, @identity)
        @identity.recording_studio_trashable_restore!(actor: current_identity_actor)
      end
      redirect_to identity_path(@identity), notice: flash_was_restored(@identity), status: :see_other
    end

    def set_image
      signed_blob_id = string_param(:image, :signed_blob_id)
      unless signed_blob_id
        return redirect_to(edit_identity_path(@identity), alert: flash_choose_image, status: :see_other)
      end

      RecordingStudioIdentity.set_image(@identity, signed_blob_id: signed_blob_id, actor: current_identity_actor)
      redirect_to edit_identity_path(@identity), notice: flash_image_updated, status: :see_other
    rescue ImageRejected => e
      redirect_to edit_identity_path(@identity), alert: user_message(e.message), status: :see_other
    end

    def remove_image
      RecordingStudioIdentity.remove_image(@identity, actor: current_identity_actor)
      redirect_to edit_identity_path(@identity), notice: flash_image_removed, status: :see_other
    rescue ImageRejected => e
      redirect_to edit_identity_path(@identity), alert: user_message(e.message), status: :see_other
    end

    private

    def set_parent
      @parent = RecordingStudio::Recording.unscoped.find_by(id: params[:recording_id])
      return if @parent && @parent.trashed_at.nil? && RecordingStudioIdentity.allowance(@parent) &&
                identity_can?(:view, @parent)

      raise NotFound, "No identity parent #{params[:recording_id].inspect}"
    end

    def set_identity
      @identity = RecordingStudioIdentity.find(params[:id], include_trashed: true)
      raise NotFound, "No identity #{params[:id].inspect}" unless identity_can?(:view, @identity)
    end

    def selected_category
      categories = RecordingStudioIdentity.categories
      return categories.first if categories.one?

      kind = string_param(:kind) || string_param(:identity, :kind)
      return if kind.blank?

      RecordingStudioIdentity.category(kind)
    end

    def submitted_image_blob_id
      blob_id = string_param(:image, :signed_blob_id)
      return if blob_id.blank?
      return blob_id unless image_param.key?(:file)
      return blob_id if uploaded_image_file?

      nil
    end

    def remove_submitted_image?
      string_param(:image, :remove) == "1" && submitted_image_blob_id.blank?
    end

    def uploaded_image_file?
      file = image_param[:file]
      file.respond_to?(:original_filename) && file.original_filename.present?
    end

    def image_param
      image = params[:image]
      image.is_a?(ActionController::Parameters) ? image : ActionController::Parameters.new
    end

    def identity_params
      params.expect(identity: Identity::CREATE_FIELDS).to_h.symbolize_keys
    end

    def update_params
      params.expect(identity: Identity::UPDATE_FIELDS).to_h.symbolize_keys
    end

    def user_message(message)
      ::RecordingStudioIdentity::Copy.user_message(message)
    end

    def flash_cant_add
      identity_copy("flashes.cant_add", "An identity can't be added here.")
    end

    def flash_was_added(identity)
      name = identity.recordable.name
      identity_copy("flashes.was_added", "#{name} was added.", name: name)
    end

    def flash_was_saved(identity)
      name = identity.recordable.name
      identity_copy("flashes.was_saved", "#{name} was saved.", name: name)
    end

    def flash_in_trash(identity)
      name = identity.recordable.name
      identity_copy("flashes.in_trash", "#{name} is in the trash.", name: name)
    end

    def flash_was_restored(identity)
      name = identity.recordable.name
      identity_copy("flashes.was_restored", "#{name} was restored.", name: name)
    end

    def flash_cant_edit(identity)
      name = identity.recordable.name
      identity_copy("flashes.cant_edit", "You can't edit #{name}.", name: name)
    end

    def flash_choose_image
      identity_copy("flashes.choose_image", "Choose an image to upload.")
    end

    def flash_image_updated
      identity_copy("flashes.image_updated", "The image was updated.")
    end

    def flash_image_removed
      identity_copy("flashes.image_removed", "The image was removed.")
    end
  end
end
