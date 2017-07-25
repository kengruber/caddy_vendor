Rails.application.routes.draw do
  
  resources :sms_messages
  require 'sidekiq/web'
  mount Sidekiq::Web => '/sidekiq'
  
  get 'reports' => 'reports#index'
  get 'reports/clear_member_balances' => 'reports#clear_member_balances'
  
#  resources :reports
  resources :transactions
  resources :customers do
    member do
      get :clear_account_balance
    end
    collection do
      get :clear_all_account_balances
    end
  end
  resources :transfers
  resources :companies
  devise_for :users
  resources :players do
    member do
      put 'update_tip'
      put 'update_caddy_fee'
      put 'update_transaction_fee'
    end
  end
  resources :caddies do
    member do
      get 'pay'
    end
    collection do
      get 'send_group_text_message'
    end
  end
  resources :members
  resources :courses
  resources :events do 
    collection do
      get 'calendar'
    end
  end
  resources :caddy_pay_rates
  resources :caddy_rank_descs
  
  resources :caddy_ratings
#  resources :users
  resources :users_admin, :controller => 'users'
  
  resources :vendor_payables
  
  get 'welcome/index'
  root 'welcome#index'
end
