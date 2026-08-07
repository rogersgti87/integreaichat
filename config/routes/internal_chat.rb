# Internal Chat API routes — kept isolated for easier Chatwoot upgrades.
# Loaded from config/routes.rb inside the account-scoped API block.

namespace :internal_chat do
  resources :conversations, only: [:index, :create, :show], controller: '/internal_chat/conversations' do
    member do
      post :mark_as_read
    end
    collection do
      get :unread_count
    end
    resources :messages, only: [:index, :create], controller: '/internal_chat/messages' do
      collection do
        post :typing
      end
    end
    resources :participants, only: [:index], controller: '/internal_chat/participants'
  end

  resources :users, only: [:index], controller: '/internal_chat/users'
  get :search, to: '/internal_chat/searches#index'
end
