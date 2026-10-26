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
    @first_month = [ published.minimum(:published_at)&.in_time_zone&.to_date&.beginning_of_month || today, today ].min
    @heatmap_data = published
      .where(published_at: @current_month.beginning_of_day...(@current_month + 1.month).beginning_of_day)
      .pluck(:published_at)
      .group_by { |t| t.in_time_zone.to_date.to_s }
      .transform_values(&:count)

    scope = published.includes(:tags).order(published_at: :desc, id: :desc)
    scope = scope.where(published_at: @selected_date.beginning_of_day...@selected_date.next_day.beginning_of_day) if @selected_date
    @pagy, @thoughts = pagy(scope, limit: 20)
  end

  def show
    @thought = Thought.status_published.friendly.find(params[:id])
  end
end
