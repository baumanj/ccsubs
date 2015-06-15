Ccsubs::Application.routes.draw do
  resources :availabilities, only: [:index, :create, :destroy]
  get '/availabilities/:id', to: 'availabilities#index'
  resources :users
  resources :requests
  get '/requests/:user_id/pending', to: 'requests#pending', as: :pending_requests
  patch '/requests/:id/offer/sub', to: 'requests#offer_sub', as: :offer_sub
  patch '/requests/:id/offer/swap', to: 'requests#offer_swap', as: :offer_swap
  patch '/requests/:id/accept/swap', to: 'requests#accept_swap', as: :accept_swap
  patch '/requests/:id/decline/swap', to: 'requests#decline_swap', as: :decline_swap
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
