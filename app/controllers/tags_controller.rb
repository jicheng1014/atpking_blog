class TagsController < ApplicationController
  allow_unauthenticated_access # 允许未登录访问所有动作

  def index
    @tags = Tag.left_joins(:posts)
              .group(:id)
              .select('tags.*, COUNT(posts.id) as posts_count')
              .order('posts_count DESC')

    Rails.logger.debug "Template Paths: #{view_paths.inspect}"
    Rails.logger.debug "Looking for template: #{template_exists?('index', 'tags', :html)}"
    Rails.logger.debug "Available Formats: #{formats.inspect}"

    respond_to do |format|
      format.html
      format.json { render json: @tags }
    end
  end

  def show
    @tag = Tag.friendly.find(params[:id])
    @posts = @tag.posts.status_published.order(created_at: :desc)
  end
end
