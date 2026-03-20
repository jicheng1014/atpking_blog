class Admin::ThoughtsController < Admin::ApplicationController
  before_action :set_thought, only: [:edit, :update, :destroy]

  def index
    @thoughts = current_user.posts.where(type: 'Thought').order(created_at: :desc)
    @thought = Thought.new
  end

  def create
    @thought = Thought.new(thought_params)
    @thought.user = current_user

    if @thought.save
      redirect_to admin_thoughts_path, notice: '灵感已发布'
    else
      @thoughts = current_user.posts.where(type: 'Thought').order(created_at: :desc)
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @thought.update(thought_params)
      redirect_to admin_thoughts_path, notice: '灵感已更新'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @thought.destroy
    redirect_to admin_thoughts_path, notice: '灵感已删除'
  end

  private

  def set_thought
    @thought = current_user.posts.where(type: 'Thought').friendly.find(params[:id])
  end

  def thought_params
    params.require(:thought).permit(:content, :status, :tag_list)
  end
end
