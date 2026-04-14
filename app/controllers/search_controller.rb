class SearchController < ApplicationController
  def index
    query = params[:q].to_s.strip
    offset = params[:offset].to_i
    source = params[:source].presence || :mangadex

    if query.blank?
      render json: { results: [], total: 0 }
      return
    end

    adapter = AdapterRegistry.for_source(source.to_sym)

    if adapter.nil?
      render json: { results: [], total: 0, error: "Unknown source" }
      return
    end

    sort = params[:sort].presence || "relevance"
    data = adapter.search_manga(query, limit: 5, offset: offset, sort: sort)
    render json: data
  end
end
