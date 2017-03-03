class ReportsController < ApplicationController
  before_action :authenticate_user!
#  before_action :set_report, only: [:show, :edit, :update, :destroy]
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
#        @transfers = @club.transfers.where(created_at: @start_date.to_date.beginning_of_day..@end_date.to_date.end_of_day, reversed: false).where.not(ez_cash_tran_id: [nil, '']).order("#{reports_sort_column} #{reports_sort_direction}").page(params[:page]).per(20)
        @transfers = @club.transfers.where(created_at: @start_date.to_date.beginning_of_day..@end_date.to_date.end_of_day, reversed: false).where.not(ez_cash_tran_id: [nil, '']).order("created_at DESC")
        @transfers_total = 0
        @transfers.each do |transfer|
          @transfers_total = @transfers_total + transfer.total unless transfer.total.blank?
        end
        @transactions = current_user.company.transactions.where(date_time: @start_date.to_date.beginning_of_day..@end_date.to_date.end_of_day, tran_code: 'CARD', sec_tran_code: ['TFR', 'TFR ']).where.not(tran_code: ['FEE', 'FEE '], amt_auth: [nil]).order("date_time DESC")
        @transactions_total = 0
        @transactions.each do |transaction|
          @transactions_total = @transactions_total + transaction.total unless transaction.total.blank?
        end
        @members_balance_total = 0
        @transfers.each do |transfer|
          @members_balance_total = @members_balance_total + transfer.from_account_record.balance unless transfer.customer.blank? or transfer.from_account_record.blank? or transfer.member_balance_cleared?
        end
      }
      format.csv { 
        @transfers = @club.transfers.where(created_at: @start_date.to_date.beginning_of_day..@end_date.to_date.end_of_day, reversed: false).where.not(ez_cash_tran_id: [nil, ''])
        send_data @transfers.to_csv, filename: "transfers-#{Date.today}.csv" 
        }
    end
    
  end
  
  def clear_member_balances
    unless report_params[:club_id].blank?
      @club = Club.where(ClubCourseID: report_params[:club_id]).first
      @club = current_club.blank? ? current_user.company.clubs.first : current_club if @club.blank?
    else
      @club = current_club.blank? ? current_user.company.clubs.first : current_club
    end
    
    @start_date = @club.date_of_last_one_sided_credit_transaction.to_s
    @start_date = Date.today.beginning_of_day.to_s if @start_date.blank?
    @end_date = Date.today.end_of_day.to_s
    
    # Need to add 5 hours to because the transaction's date_time in stored as Eastern time
    @transfers = @club.transfers.where(created_at: (@start_date.to_datetime + 5.hours)..@end_date.to_datetime, reversed: false, member_balance_cleared: false).where.not(ez_cash_tran_id: [nil, '']).order("created_at DESC")
    @transfers_total = 0
    @transfers.each do |transfer|
      @transfers_total = @transfers_total + transfer.total unless transfer.total.blank?
    end
    
    # Use current user's time zone since transactions are stored in east coast time
#    @transactions = current_user.company.transactions.where(date_time: @start_date.to_datetime..@end_date.to_datetime, tran_code: 'CARD', sec_tran_code: ['TFR', 'TFR ']).where.not(tran_code: ['FEE', 'FEE '], amt_auth: [nil]).order("date_time DESC")
#    @transactions_total = 0
#    @transactions.each do |transaction|
#      @transactions_total = @transactions_total + transaction.total unless transaction.total.blank?
#    end
    
    @members_balance_total = 0
    @transfers.each do |transfer|
      @members_balance_total = @members_balance_total + transfer.from_account_record.balance unless transfer.customer.blank? or transfer.from_account_record.blank? or transfer.member_balance_cleared?
    end
    unless params[:clearing_member_balances].blank? or @transfers_total.zero?
      @club.perform_one_sided_credit_transaction(@transfers_total)
      @transfers.each do |transfer|
        unless transfer.customer.blank? 
          ClearMemberBalanceWorker.perform_async(transfer.id) # Clear transfer member's balance with sidekiq background process
        end
      end
      flash[:notice] = "Request to clear member balances submitted to EZcash."
      redirect_to reports_path
    end
#    redirect_back(fallback_location: root_path)
  end

  private

    # Never trust parameters from the scary internet, only allow the white list through.
    def report_params
#      params.require(:report).permit(:start_date, :end_date, :type)
      params.fetch(:report, {}).permit(:start_date, :end_date, :type, :club_id, :clear_member_balances)
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
