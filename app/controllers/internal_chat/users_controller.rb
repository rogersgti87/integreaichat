# frozen_string_literal: true

class InternalChat::UsersController < InternalChat::BaseController
  def index
    users = InternalChat::SearchUsers.new(
      account: Current.account,
      query: params[:q],
      exclude_user_id: Current.user.id
    ).perform

    payload = users.map do |user|
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

    render json: { payload: payload }
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
