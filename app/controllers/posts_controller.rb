class PostsController < ApplicationController
  allow_unauthenticated_access # 允许未登录访问所有动作

  def index
    @article_index = request.path == posts_path
    @posts = Post.only_posts.status_published.includes(:user, :tags)

    if params[:tag].present?
      @tag = Tag.find_by!(slug: params[:tag])
      @article_index = true
      @posts = @posts.joins(:tags).where(tags: { id: @tag.id })
    end

    @pagy, @posts = pagy(@posts.order(created_at: :desc), limit: 20)
    @all_tags = Tag.left_joins(:posts).where(posts: { status: 'published', type: nil })
                   .group(:id).select('tags.*, COUNT(posts.id) as posts_count')
                   .having('COUNT(posts.id) > 0').order('posts_count DESC')
    @recent_thoughts = Thought.status_published.order(published_at: :desc, id: :desc).limit(5)
    @rhythm_month = Date.current.beginning_of_month
    @rhythm_counts = Thought.status_published
      .where(published_at: @rhythm_month.beginning_of_day...(@rhythm_month + 1.month).beginning_of_day)
      .pluck(:published_at)
      .map { |time| time.in_time_zone.day }
      .tally
  end

  def show
    @post = Post.only_posts.status_published.friendly.find(params[:id])
    @comment = Comment.new
    @comments = @post.comments.includes(:user).order(created_at: :desc)
  end

  def feed
    @posts = Post.only_posts.status_published.order(created_at: :desc).limit(20)
    respond_to do |format|
      format.rss { render layout: false }
    end
  end

  private

  def set_post
    @post = Post.friendly.find(params[:id])
  end
end
