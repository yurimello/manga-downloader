class ChapterSelectorService
  def initialize(priorities: nil)
    @priorities = priorities || LanguageLoader.priorities
  end

  def select(chapters, volumes: nil)
    best = {}

    chapters.each do |ch|
      num = ch[:chapter]
      priority = @priorities[ch[:language]] || 99
      if !best[num] || priority < best[num][:priority]
        best[num] = ch.merge(priority: priority)
      end
    end

    selected = best.values
      .sort_by { |ch| Float(ch[:chapter]) rescue 0 }
      .map { |ch| ch.except(:priority) }

    if volumes.present?
      vol_list = volumes.map(&:to_s)
      selected = selected.select { |ch| vol_list.include?(ch[:volume].to_s) }
    end

    selected
  end

  def language_summary(chapters)
    chapters.each_with_object(Hash.new(0)) do |ch, counts|
      counts[ch[:language]] += 1
    end
  end
end
