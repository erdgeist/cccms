class RelatedAssetsController < ApplicationController
  before_action :login_required
  before_action :find_node

  def search
    term = params[:q].to_s.strip
    if term.blank?
      render json: []
      return
    end

    attached_ids = @node.editable_page.related_assets.pluck(:asset_id)
    results = Asset.images
      .where("name ILIKE ?", "%#{term}%")
      .where.not(id: attached_ids)
      .limit(10)

    render json: results.map { |a|
      { id: a.id, name: a.name, thumb_url: a.upload.url(:thumb) }
    }
  end

  def create
    asset = Asset.find(params[:asset_id])
    related = @node.editable_page.related_assets.find_or_create_by!(asset: asset)

    render json: {
      id: related.id,
      asset_id: asset.id,
      name: asset.name,
      thumb_url: asset.upload.url(:thumb)
    }
  end

  def destroy
    @node.editable_page.related_assets.find(params[:id]).destroy
    head :ok
  end

  def update
    @node.editable_page.related_assets.find(params[:id]).insert_at(params[:position].to_i)
    head :ok
  end

  private

    def find_node
      @node = Node.find(params[:node_id])
    end
end
