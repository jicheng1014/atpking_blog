class TagsController < ApplicationController
  allow_unauthenticated_access # 允许未登录访问所有动作

  def index
    @tags = Tag.joins(:posts).where(posts: { status: "published" })
              .group(:id)
              .select('tags.*, COUNT(posts.id) as posts_count')
              .order('posts_count DESC')

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
