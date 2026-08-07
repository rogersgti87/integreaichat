# frozen_string_literal: true

class InternalChat::ParticipantsController < InternalChat::BaseController
  before_action :find_participating_conversation!

  def index
    participants = @conversation.participants
                                .for_account(Current.account.id)
                                .includes(:user)

    payload = participants.map do |participant|
      user = participant.user
      account_user = AccountUser.find_by(account_id: Current.account.id, user_id: user.id)
      {
        id: participant.id,
        user_id: user.id,
        name: user.name,
        available_name: user.available_name,
        avatar_url: user.avatar_url,
        role: account_user&.role,
        availability_status: availability_status_for(user.id),
        last_read_message_id: participant.last_read_message_id
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
