class Admin::PostsController < Admin::ApplicationController
  before_action :set_post, only: [:show, :edit, :update, :destroy]

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

    begin
      # 验证文件类型
      unless image.content_type.start_with?('image/')
        return render json: { error: '只能上传图片文件' }, status: :unprocessable_entity
      end

      # 验证文件大小（例如限制为 10MB）
      if image.size > 10.megabytes
        return render json: { error: '图片大小不能超过 10MB' }, status: :unprocessable_entity
      end

      # 使用 Active Storage 处理上传
      blob = ActiveStorage::Blob.create_and_upload!(
        io: image,
        filename: image.original_filename,
        content_type: image.content_type,
        metadata: {
          identified: true,
          analyzed: true,
          processed: false  # 标记为未处理
        }
      )

      # 返回原始图片的 URL
      url = rails_blob_path(blob, only_path: true)

      # 记录上传成功的日志
      Rails.logger.info "Successfully uploaded image: #{blob.filename} (#{blob.byte_size} bytes) for user #{current_user.id}"

      render json: {
        markdown: "![#{image.original_filename}](#{url})",
        blob_signed_id: blob.signed_id,
        url: url
      }
    rescue => e
      Rails.logger.error "Failed to upload image: #{e.message}"
      render json: { error: '图片上传失败，请重试' }, status: :unprocessable_entity
    end
  end

  private

  def set_post
    @post = current_user.posts.friendly.find(params[:id])
  end

  def post_params
    params.require(:post).permit(*Post.permitted_attributes)
  end
end
