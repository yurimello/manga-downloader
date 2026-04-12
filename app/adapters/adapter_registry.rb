class AdapterRegistry
  class << self
    def instance
      @instance ||= new
    end

    delegate :for_url, :for_source, :register, to: :instance
  end

  def initialize
    @adapters = {}
  end

  def register(name, adapter)
    @adapters[name.to_s] = adapter
  end

  def for_url(url)
    @adapters.each_value do |adapter|
      return adapter if url.match?(adapter.url_pattern)
    end
    nil
  end

  def for_source(name)
    @adapters[name.to_s]
  end

  def sources
    @adapters.keys
  end
end
