Rails.application.routes.draw do
  resource :session
  # 设置首页为文章列表
  root "posts#index"

  # 公开可访问的路由（只读）
  resources :posts, only: [:index, :show] do
    resources :comments, only: [:create, :destroy]
    collection do
      get :feed, defaults: { format: 'rss' }
    end
  end

  # 管理界面路由，需要登录
  namespace :admin do
    root to: "posts#index"
    resources :posts do
      collection do
        post :upload_image
      end
    end

    # 挂载任务队列管理界面
    mount MissionControl::Jobs::Engine => "/jobs", as: 'mission_control_jobs'
  end

  # 认证相关路由
  resource :session, only: [:new, :create, :destroy]
  resources :passwords, param: :token

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
