class ReportsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_report, only: [:show, :edit, :update, :destroy]
#  load_and_authorize_resource

  helper_method :reports_sort_column, :reports_sort_direction
  
  # GET /reports
  # GET /reports.json
  def index
    @start_date = report_params[:start_date] ||= Date.today.to_s
    @end_date = report_params[:end_date] ||= Date.today.to_s
    unless report_params[:club_id].blank?
      @club = Club.where(ClubCourseID: report_params[:club_id]).first
      @club = current_club.blank? ? current_user.company.clubs.first : current_club if @club.blank?
    else
      @club = current_club.blank? ? current_user.company.clubs.first : current_club
    end
    
    respond_to do |format|
      format.html {
        @transfers = @club.transfers.where(created_at: @start_date.to_date.beginning_of_day..@end_date.to_date.end_of_day, reversed: false).where.not(ez_cash_tran_id: [nil, '']).order("#{reports_sort_column} #{reports_sort_direction}").page(params[:page]).per(20)
      }
      format.csv { 
        @transfers = @club.transfers.where(created_at: @start_date.to_date.beginning_of_day..@start_date.to_date.end_of_day, reversed: false).where.not(ez_cash_tran_id: [nil, ''])
        send_data @transfers.to_csv, filename: "transfers-#{Date.today}.csv" 
        }
    end
    
  end

  private

    # Never trust parameters from the scary internet, only allow the white list through.
    def report_params
#      params.require(:report).permit(:start_date, :end_date, :type)
      params.fetch(:report, {}).permit(:start_date, :end_date, :type, :club_id)
    end
    
    ### Secure the reports sort direction ###
    def reports_sort_direction
      %w[asc desc].include?(params[:reports_direction]) ?  params[:reports_direction] : "desc"
    end

    ### Secure the reports sort column name ###
    def reports_sort_column
      ["ez_cash_tran_id", "created_at", "from_account_id", "to_account_id", "caddy_fee_cents", "caddy_tip_cents", "amount_cents", "fee_cents", "fee_to_account_id"].include?(params[:reports_column]) ? params[:reports_column] : "created_at"
    end
end
