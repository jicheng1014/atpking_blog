class ThoughtsController < ApplicationController
  allow_unauthenticated_access

  def index
    @thoughts = Thought.status_published.includes(:tags).order(created_at: :desc)
    @pagy, @thoughts = pagy(@thoughts, limit: 20)
  end

  def show
    @thought = Thought.status_published.friendly.find(params[:id])
  end
end
