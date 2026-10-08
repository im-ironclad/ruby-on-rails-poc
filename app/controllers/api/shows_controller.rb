module Api
  class ShowsController < BaseController
    def index
      shows = Show.includes(:list_entry).order(:title)
      render json: shows.map { |show| ShowSerializer.call(show) }
    end
  end
end
