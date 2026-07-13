class RelatedAssetsController < ApplicationController
  before_action :login_required
  before_action :find_node

  def search
    term = params[:search_term].to_s.strip
    attached_ids = @node.editable_page.related_assets.pluck(:asset_id)
    scope = Asset.images.where.not(id: attached_ids)

    results = if term.present?
      scope.where("name ILIKE ?", "%#{term}%").limit(10)
    else
      scope.order(created_at: :desc).limit(5)
    end

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
      thumb_url: asset.upload.url(:thumb),
      url: node_related_asset_path(@node, related)
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
