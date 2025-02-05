class CommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_post
  before_action :set_comment, only: [:destroy]
  before_action :authorize_user!, only: [:destroy]

  def create
    @comment = @post.comments.new(comment_params)
    @comment.user = current_user

    if @comment.save
      redirect_to @post, notice: '评论发表成功'
    else
      redirect_to @post, alert: '评论发表失败'
    end
  end

  def destroy
    @comment.destroy
    redirect_to @post, notice: '评论已删除'
  end

  private

  def set_post
    @post = Post.find(params[:post_id])
  end

  def set_comment
    @comment = @post.comments.find(params[:id])
  end

  def comment_params
    params.require(:comment).permit(:content)
  end

  def authorize_user!
    unless @comment.user_id == current_user.id
      redirect_to @post, alert: '您没有权限执行此操作'
    end
  end
end
