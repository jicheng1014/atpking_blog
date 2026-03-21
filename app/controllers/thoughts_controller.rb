class ThoughtsController < ApplicationController
  allow_unauthenticated_access

  def index
    @thought = Thought.new if current_user

    today = Date.current.beginning_of_month
    @current_month = if params[:month]
      [ (Date.parse("#{params[:month]}-01") rescue today), today ].min
    else
      today
    end

    @selected_date = params[:date] ? (Date.parse(params[:date]) rescue nil) : nil

    published = Thought.status_published

    # Group by date in Ruby (not SQL DATE()) to respect Rails timezone (UTC+8 for Chinese audience)
    @heatmap_data = published
      .where(created_at: @current_month.beginning_of_day..@current_month.end_of_month.end_of_day)
      .pluck(:created_at)
      .group_by { |t| t.to_date.to_s }
      .transform_values(&:count)

    scope = published.includes(:tags).order(created_at: :desc)
    scope = scope.where(created_at: @selected_date.beginning_of_day..@selected_date.end_of_day) if @selected_date
    @pagy, @thoughts = pagy(scope, limit: 20)
  end

  def show
    @thought = Thought.status_published.friendly.find(params[:id])
  end
end
