Rails.application.config.after_initialize do
  config = Rails.application.config_for(:sources)
  sources = config[:sources] || config

  sources.each do |name, adapter_config|
    adapter_class = adapter_config[:adapter_class].to_s.constantize
    AdapterRegistry.register(name, adapter_class.new(adapter_config.stringify_keys))
  end
rescue => e
  Rails.logger.warn "Failed to load source adapters: #{e.message}"
end
