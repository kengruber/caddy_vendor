class Course < ApplicationRecord
  self.primary_key = 'ClubCourseID'
  self.table_name= 'CaddyCourses'
  
  establish_connection :ez_cash
  
  belongs_to :company, :foreign_key => "ClubCompanyNumber"
  has_many :events
  has_many :caddies
  has_many :caddy_pay_rates
  has_many :caddy_rank_descs
#  has_many :transfers #, through: :events
  has_many :accounts
  has_many :players, through: :events
  
  attr_accessor :transaction_fee

  #############################
  #     Instance Methods      #
  #############################
  
  def name
    self.CourseName
  end
  
  def caddy_rankings_array
    rankings = []
    caddy_rank_descs.each do |caddy_rank|
      rankings << caddy_rank.RankingAcronym
    end
    return rankings.uniq
  end
  
  def grouped_caddies_for_select
    [
      ['Checked In',  caddies.active.select{|caddy| caddy.checkin_today?}.sort_by {|c| c.caddy_rank_desc}.collect { |c| [ c.full_name, c.id ] }],
      ['Checked Out',  caddies.active.select{|caddy| not caddy.checkin_today?}.sort_by {|c| c.caddy_rank_desc}.collect { |c| [ c.full_name, c.id ] }]
    ]
  end
  
  def grouped_caddies_by_status_for_select
    [
      ['Checked In',  caddies.active.select{|caddy| caddy.checkin_today?}.sort_by {|c| c.caddy_rank_desc}.collect { |c| [ c.full_name_with_rank, c.id ] }],
      ['Checked Out',  caddies.active.select{|caddy| not caddy.checkin_today?}.sort_by {|c| c.caddy_rank_desc}.collect { |c| [ c.full_name_with_rank, c.id ] }]
    ]
  end
  
  def grouped_caddies_by_rank_for_select
    caddy_rank_descs.map{|c| c.grouped_for_select}
  end
  
  ### Start Virtual Attributes ###
  def transaction_fee # Getter
    transaction_fee_cents.to_d / 100 if transaction_fee_cents
  end
  
  def transaction_fee=(dollars) # Setter
    self.transaction_fee_cents = dollars.to_d * 100 if dollars.present?
  end
  ### End Virtual Attributes ###
  
  def account
    Account.where(CompanyNumber: company.id, CustomerID: nil).first
  end
  
  def perform_one_sided_credit_transaction(amount)
    unless account.blank?
      transaction_id = account.ezcash_one_sided_credit_transaction_web_service_call(amount) 
      Rails.logger.debug "*************** One-sided EZcash transaction #{transaction_id}"
      return transaction_id
    end
  end
  
  def balance
    account.Balance unless account.blank?
  end
  
  def player_notes
    players.where.not(note: [nil, '']).collect { |p| [ p.note ] }.insert(0,['None']).uniq
  end
  
  def caddy_types
    caddy_pay_rates.collect { |cpr| [ cpr.Type ] }.uniq.sort
  end
  
  #############################
  #     Class Methods         #
  #############################
end
