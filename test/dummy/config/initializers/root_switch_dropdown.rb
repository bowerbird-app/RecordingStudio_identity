# frozen_string_literal: true

# Root switchable 0.10 still renders its trigger with FlatPack's removed
# button_attributes helper. FlatPack 0.1.320 builds that button with
# render_trigger_button. Draw the same wrapper and rows.
module RootSwitchDropdownTrigger
  def call
    content_tag(:div, **wrapper_attributes) do
      safe_join([
        render_trigger_button,
        content_tag(:div, **menu_attributes) do
          render(RecordingStudioRootSwitchable::RootSwitch::RowsComponent.new(menu_rows: menu_rows))
        end
      ])
    end
  end
end

Rails.application.config.to_prepare do
  component = RecordingStudioRootSwitchable::RootSwitch::DropdownComponent
  next if component < RootSwitchDropdownTrigger

  component.prepend(RootSwitchDropdownTrigger)
end
