class LanguageConfig
  def self.codes
    config["languages"].sort_by { |l| l["priority"] }.map { |l| l["code"] }
  end

  def self.priorities
    config["languages"].each_with_object({}) do |lang, hash|
      hash[lang["code"]] = lang["priority"]
    end
  end

  def self.config
    @config ||= YAML.load_file(Rails.root.join("config", "languages.yml"))
  end
end
