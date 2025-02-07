class Admin::PostsController < ApplicationController
  before_action :authenticated?
  before_action :set_post, only: [:show, :edit, :update, :destroy]
  layout 'admin'

  def index
    @posts = current_user.posts.order(created_at: :desc)
  end

  def show
    @comments = @post.comments.includes(:user).order(created_at: :desc)
  end

  def new
    @post = current_user.posts.new
  end

  def create
    @post = current_user.posts.new(post_params)

    if @post.save
      redirect_to admin_posts_path, notice: '文章创建成功'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @post.update(post_params)
      redirect_to admin_posts_path, notice: '文章更新成功'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @post.destroy
    redirect_to admin_posts_path, notice: '文章已删除'
  end

  def upload_image
    image = params[:image]
    return render json: { error: '没有上传图片' }, status: :unprocessable_entity unless image

    # 使用 Active Storage 处理上传
    blob = ActiveStorage::Blob.create_and_upload!(
      io: image,
      filename: image.original_filename,
      content_type: image.content_type
    )

    # 返回 Markdown 格式的图片链接
    url = Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)
    render json: { markdown: "![#{image.original_filename}](#{url})" }
  end

  private

  def set_post
    @post = current_user.posts.find(params[:id])
  end

  def post_params
    params.require(:post).permit(:title, :content, :status, :tag_list)
  end
end
