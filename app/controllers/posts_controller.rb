class PostsController < ApplicationController
  allow_unauthenticated_access # 允许未登录访问所有动作

  def index
    @posts = Post.published.includes(:user)

    if params[:tag].present?
      @tag = Tag.find_by!(slug: params[:tag])
      @posts = @posts.joins(:tags).where(tags: { id: @tag.id })
    end

    @posts = @posts.order(created_at: :desc)
  end

  def show
    @post = Post.published.find(params[:id])
    @comment = Comment.new
    @comments = @post.comments.includes(:user).order(created_at: :desc)
  end
end
