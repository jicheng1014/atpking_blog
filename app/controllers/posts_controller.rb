class PostsController < ApplicationController
  allow_unauthenticated_access # 允许未登录访问所有动作

  def index
    @posts = Post.status_published.includes(:user, :tags)

    if params[:tag].present?
      @tag = Tag.find_by!(slug: params[:tag])
      @posts = @posts.joins(:tags).where(tags: { id: @tag.id })
    end

    @pagy, @posts = pagy(@posts.order(created_at: :desc), limit: 20)
    @all_tags = Tag.left_joins(:posts).where(posts: { status: 'published' })
                   .group(:id).select('tags.*, COUNT(posts.id) as posts_count')
                   .having('COUNT(posts.id) > 0').order('posts_count DESC')
  end

  def show
    @post = Post.status_published.friendly.find(params[:id])
    @comment = Comment.new
    @comments = @post.comments.includes(:user).order(created_at: :desc)
  end

  def feed
    @posts = Post.status_published.order(created_at: :desc).limit(20)
    respond_to do |format|
      format.rss { render layout: false }
    end
  end

  private

  def set_post
    @post = Post.friendly.find(params[:id])
  end
end
