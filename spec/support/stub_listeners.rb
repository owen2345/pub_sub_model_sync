# frozen_string_literal: true

module StubListeners
  # @param args (Hash): {as_klass: , as_action: , direct_mode: }
  # @param settings (Hash): { id:, attrs: }
  def stub_listener(model, action, args: {}, settings: {})
    settings = { id: :id, attrs: %i[name email age] }.merge(settings)
    listener = model.send(:add_ps_subscriber, args[:as_klass], action,
                          args[:as_action], args[:direct_mode], settings)
    allow_any_instance_of(described_class).to receive(:filter_listeners) do
      [listener]
    end
  end
end

RSpec.configure do |config|
  config.include StubListeners
end
