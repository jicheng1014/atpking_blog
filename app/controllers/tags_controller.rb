class TagsController < ApplicationController
  def index
    @tags = Tag.left_joins(:posts)
              .group(:id)
              .select('tags.*, COUNT(posts.id) as posts_count')
              .order('posts_count DESC')
  end

  def show
    @tag = Tag.friendly.find(params[:id])
    @posts = @tag.posts.published.order(created_at: :desc)
  end
end
