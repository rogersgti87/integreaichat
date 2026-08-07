# frozen_string_literal: true

class InternalChatChannel < ApplicationCable::Channel
  def subscribed
    reject && return unless current_user && current_account

    stream_from stream_name
  end

  def unsubscribed
    stop_all_streams
  end

  def typing(data)
    conversation = find_conversation(data['conversation_id'])
    return if conversation.blank?

    event = data['typing'] == false ? InternalChat::Broadcast::EVENTS[:typing_off] : InternalChat::Broadcast::EVENTS[:typing_on]
    InternalChat::Broadcast.to_participants(
      conversation,
      event,
      {
        user_id: current_user.id,
        user_name: current_user.available_name.presence || current_user.name
      },
      except_user_id: current_user.id
    )
  end

  private

  def stream_name
    "internal_chat_#{current_account.id}_#{current_user.id}"
  end

  def current_user
    @current_user ||= User.find_by(pubsub_token: params[:pubsub_token], id: params[:user_id])
  end

  def current_account
    return if current_user.blank?

    @current_account ||= current_user.accounts.find_by(id: params[:account_id])
  end

  def find_conversation(conversation_id)
    InternalChat::Conversation.for_user(current_account.id, current_user.id).find_by(id: conversation_id)
  end
end
