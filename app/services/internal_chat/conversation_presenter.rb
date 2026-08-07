# frozen_string_literal: true

class InternalChat::ConversationPresenter
  pattr_initialize [:conversation!, :current_user!]

  def as_json
    {
      id: conversation.id,
      account_id: conversation.account_id,
      conversation_type: conversation.conversation_type,
      created_by_id: conversation.created_by_id,
      last_message_at: conversation.last_message_at&.to_i,
      created_at: conversation.created_at.to_i,
      updated_at: conversation.updated_at.to_i,
      unread_count: conversation.unread_count_for(current_user.id),
      participants: participants_payload,
      last_message: last_message_payload,
      display_name: display_name,
      display_avatar_url: display_avatar_url
    }
  end

  private

  def participants_payload
    conversation.participants.for_account(conversation.account_id).includes(:user).map do |participant|
      user = participant.user
      account_user = AccountUser.find_by(account_id: conversation.account_id, user_id: user.id)
      {
        id: participant.id,
        user_id: user.id,
        name: user.name,
        available_name: user.available_name,
        avatar_url: user.avatar_url,
        role: account_user&.role,
        availability_status: availability_status_for(user.id),
        last_read_message_id: participant.last_read_message_id,
        joined_at: participant.joined_at
      }
    end
  end

  def last_message_payload
    message = conversation.messages.for_account(conversation.account_id).active.order(created_at: :desc, id: :desc).first
    return nil if message.blank?

    {
      id: message.id,
      content: message.content,
      sender_id: message.sender_id,
      message_type: message.message_type,
      created_at: message.created_at.to_i
    }
  end

  def display_name
    if conversation.private?
      other = conversation.other_participant(current_user.id)&.user
      return other&.available_name || other&.name || 'Unknown'
    end

    conversation.users.where.not(id: current_user.id).map(&:name).join(', ')
  end

  def display_avatar_url
    return nil unless conversation.private?

    conversation.other_participant(current_user.id)&.user&.avatar_url
  end

  def availability_status_for(user_id)
    if OnlineStatusTracker.get_presence(conversation.account_id, 'User', user_id)
      OnlineStatusTracker.get_status(conversation.account_id, user_id) || 'online'
    else
      'offline'
    end
  end
end
