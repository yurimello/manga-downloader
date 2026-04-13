class LanguageLoaderService
  def self.call
    config = YAML.load_file(Rails.root.join("config", "languages.yml"))
    config["languages"].sort_by { |l| l["priority"] }.map { |l| l["code"] }
  end
end
