RorWebERP::Application.routes.draw do
  resources :quotations

  resources :set_prices

  resources :sales_orders do
    member do
      get 'edit_production'
      get 'production'
      get 'confirm'
      get 'invoice'
      get 'packing_list'
      put 'reschedule'
      put 'update_production'
    end
  end

  resources :attachments


  resources :prices do
    member do
      get 'apply'
    end
    collection { post :import}
  end

  resources :posts

  resources :tasks

  resources :oppostatuses

  resources :opportunities

  resources :contacts
  resources :customers do
    collection { post :import}
  end

  #resources :customers, shallow: true do
  #  resources :contacts
  #end

#  get 'admin/index', :as => 'admin'
  #get 'admin' => 'admin/index'

  controller :sessions do
    get 'login' => :new
    post 'login' => :create
    get 'logout' => :destroy
  end
  resources :admin, :only => [:index]

  # get '/signup' => 'users#new'

  resources :users
  get "users/show"


  resources :orders do
    collection { get  :reverse}
    collection { post :import}    
  end


  resources :line_items

  resources :carts

  resources :items do
    get :who_bought, :on => :member
    collection { post :import}
  end

  resources :set_prices do
    collection { post :import}
    collection { get :quotate}
  end  

  get "inventory/index"

  #get "orders/index"

  #root :to => 'orders#index', :as => 'orders'
  root :to => 'admin#index', :as => 'admin'

  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
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

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => 'welcome#index'

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id))(.:format)'
end
