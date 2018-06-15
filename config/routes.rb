Ccsubs::Application.routes.draw do
  get 'holiday_schedule(/:date)', to: 'holiday_schedule#index', as: :holiday_schedule

  resources :holiday_requests, only: [:index]

  get 'on_calls/edit(/:date)', to: 'on_calls#edit', as: :edit_on_call
  get 'on_calls(/:date)', to: 'on_calls#index', as: :on_calls
  resources :on_calls, only: [:create, :update, :destroy]

  get '/messages/new', to: 'messages#new'
  post '/messages/deliver', to: 'messages#deliver', as: :deliver_message

  resources :availabilities, only: [:create, :index, :update]
  get '/availabilities/edit_default', to: 'availabilities#edit_default', as: :edit_default_availability
  get '/availabilities/:id', to: 'availabilities#index'
  post '/users/upload_csv', to: 'users#upload_csv', as: :upload_csv
  get '/users/new_list', to: 'users#new_list', as: :new_user_list
  patch '/users/update/availability/:id', to: 'users#update_availability', as: :update_availability
  patch '/users/update/default_availability/:id', to: 'users#update_default_availability', as: :update_default_availability
  if Rails.env.development?
    delete '/users/delete/all/availability/:id', to: 'users#delete_all_availability', as: :delete_all_availability
  end
  # patch '/users/:id/request/create', to: 'users#create_request', as: :create_user_request
  resources :users
  get '/requests/fulfilled', to: 'requests#fulfilled', as: :fulfilled_requests
  get '/requests/owned(/:user_id)', to: 'requests#owned_index', as: :owned_requests
  get '/requests/pending(/:user_id)', to: 'requests#pending', as: :pending_requests
  resources :requests, except: [:edit]
  patch '/requests/:id/sub', to: 'requests#offer_sub', as: :offer_sub
  resources :sessions, only: [:new, :create, :destroy]
  root 'static_pages#home'
  get '/help', to: 'static_pages#help', as: :help
  match '/signup',  to: 'users#new',        via: 'get'
  match '/signin',  to: 'sessions#new',     via: 'get'
  match '/signout', to: 'sessions#destroy', via: 'delete'

  get '/users/confirm/:id', to: 'users#send_confirmation', as: :send_confirmation
  get '/users/confirm/:id/:confirmation_token', to: 'users#confirm', as: :confirm_user
  get '/users/reset/password/:id/:confirmation_token', to: 'users#reset_password', as: :reset_password
  patch '/users/update/password/:id', to: 'users#update_password', as: :update_password

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
