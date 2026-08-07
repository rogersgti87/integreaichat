# frozen_string_literal: true

class InternalChat::Broadcast
  EVENTS = {
    message_created: 'internal_chat.message.created',
    conversation_created: 'internal_chat.conversation.created',
    conversation_updated: 'internal_chat.conversation.updated',
    message_read: 'internal_chat.message.read',
    typing_on: 'internal_chat.typing.on',
    typing_off: 'internal_chat.typing.off'
  }.freeze

  def self.to_participants(conversation, event_name, data, except_user_id: nil)
    tokens = conversation.participants
                         .for_account(conversation.account_id)
                         .includes(:user)
                         .filter_map do |participant|
                           next if except_user_id.present? && participant.user_id == except_user_id

                           participant.user&.pubsub_token
                         end

    return if tokens.blank?

    payload = data.merge(
      account_id: conversation.account_id,
      conversation_id: conversation.id
    )

    ActionCableBroadcastJob.perform_later(tokens.uniq, event_name, payload)
  end
end
