class GraphsController < ApplicationController
  def index
  end

  def reports_by_hour
    render :json => [
      {name: "All", data: Post.group_by_hour(:created_at, range: 1.week.ago.to_date..Time.now).count},
      {name: "True positives", data: Post.where(:is_tp => true).group_by_hour(:created_at, range: 1.week.ago.to_date..Time.now).count},
      {name: "False positives", data: Post.where(:is_fp => true).group_by_hour(:created_at, range: 1.week.ago.to_date..Time.now).count}
    ]
  end

  def reports_by_site
    if params[:timeframe] == "all"
      @posts = Post.all
    else
      @posts = Post.where("created_at >= ?", 1.month.ago)
    end
    h = HTMLEntities.new

    render :json => @posts.group(:site).count.map{ |k,v| {(k.nil? ? "Unknown" : h.decode(k.site_name))=>v} }.reduce(:merge).select{|k,v| k != "Unknown"}.sort_by {|k,v| v}.reverse
  end

  def reports_by_hour_of_day
    if params[:timeframe] == "all"
      @posts = Post.all
    else
      @posts = Post.where("created_at >= ?", 1.month.ago)
    end

    number_of_days = (DateTime.now - @posts.minimum(:created_at).to_date).to_i
    tp_posts = @posts.where(:is_tp => true).group_by_hour_of_day(:created_at).count.map{ |k,v| [k, (v.to_f / number_of_days).round(2)] }.to_h
    fp_posts = @posts.where(:is_fp => true).group_by_hour_of_day(:created_at).count.map{ |k,v| [k, (v.to_f / number_of_days).round(2)] }.to_h

    render :json => [
      {name: "All", data: @posts.group_by_hour_of_day(:created_at).count.map{ |k,v| [k, (v.to_f / number_of_days).round(2)] }.to_h},
      {name: "True positives", data: tp_posts},
      {name: "False positives", data: fp_posts}
    ]
  end

  def time_to_deletion
    render :json => Post.group_by_hour_of_day('`posts`.`created_at`').select("AVG(TIMESTAMPDIFF(SECOND, `posts`.`created_at`, `deletion_logs`.`created_at`)) as time_to_deletion")
                        .joins(:deletion_logs).where(:is_tp => true).where("TIMESTAMPDIFF(SECOND, `posts`.`created_at`, `deletion_logs`.`created_at`) <= 3600").relation.each_with_index
                        .map {|a,i| [i, a.time_to_deletion.round(0)] }
  end

  def flagging_results
    render json: [['Fail', FlagLog.where(:success => false).count], ['Dry run', FlagLog.where(:success => true, :is_dry_run => true).count],
                  ['Success', FlagLog.where(:success => true, :is_dry_run => false).count]]
  end

  def flagging_timeline
    render json: [{name: 'Failures', data: FlagLog.where(:success => false).group_by_day(:created_at, range: 1.month.ago.to_date..Time.now).count},
                  {name: 'Dry runs', data: FlagLog.where(:success => true, :is_dry_run => true).group_by_day(:created_at, range: 1.month.ago.to_date..Time.now).count},
                  {name: 'Successes', data: FlagLog.where(:success => true, :is_dry_run => false).group_by_day(:created_at, range: 1.month.ago.to_date..Time.now).count}]
  end
end
