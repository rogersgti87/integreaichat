# frozen_string_literal: true

class InternalChat::SearchesController < InternalChat::BaseController
  def index
    query = params[:q].to_s

    conversations = InternalChat::SearchConversation.new(
      account: Current.account,
      user: Current.user,
      query: query
    ).perform.includes(participants: :user).limit(20)

    users = InternalChat::SearchUsers.new(
      account: Current.account,
      query: query,
      exclude_user_id: Current.user.id
    ).perform

    render json: {
      payload: {
        conversations: conversations.map { |c| InternalChat::ConversationPresenter.new(c, current_user: Current.user).as_json },
        users: users.map do |user|
          account_user = AccountUser.find_by(account_id: Current.account.id, user_id: user.id)
          {
            id: user.id,
            name: user.name,
            available_name: user.available_name,
            email: user.email,
            avatar_url: user.avatar_url,
            role: account_user&.role,
            availability_status: availability_status_for(user.id)
          }
        end
      }
    }
  end

  private

  def availability_status_for(user_id)
    if OnlineStatusTracker.get_presence(Current.account.id, 'User', user_id)
      OnlineStatusTracker.get_status(Current.account.id, user_id) || 'online'
    else
      'offline'
    end
  end
end
