module Api
  class ListEntriesController < BaseController
    def create
      entry = ListEntry.create!(params.expect(list_entry: [:show_id, :status]))
      render json: ListEntrySerializer.call(entry), status: :created
    end

    def update
      entry = ListEntry.find(params[:id])
      entry.update!(params.expect(list_entry: [:status, :rating]))
      render json: ListEntrySerializer.call(entry)
    end

    def destroy
      ListEntry.find(params[:id]).destroy!
      head :no_content
    end
  end
end
