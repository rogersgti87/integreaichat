# frozen_string_literal: true

class InternalChat::MessagePresenter
  pattr_initialize [:message!, :viewer!]

  def as_json
    {
      id: message.id,
      account_id: message.account_id,
      conversation_id: message.conversation_id,
      sender_id: message.sender_id,
      sender: {
        id: message.sender.id,
        name: message.sender.name,
        available_name: message.sender.available_name,
        avatar_url: message.sender.avatar_url
      },
      content: message.deleted_at.present? ? '' : message.content,
      message_type: message.message_type,
      reply_to_id: message.reply_to_id,
      edited_at: message.edited_at,
      deleted_at: message.deleted_at,
      created_at: message.created_at.to_i,
      updated_at: message.updated_at.to_i,
      attachments: message.attachments.for_account(message.account_id).map(&:push_event_data),
      status: message_status
    }
  end

  private

  def message_status
    return 'deleted' if message.deleted_at.present?
    return 'sent' if message.sender_id == viewer.id && other_participant.blank?

    if message.sender_id == viewer.id
      return 'read' if read_by_others?
      return 'delivered'
    end

    'sent'
  end

  def other_participant
    @other_participant ||= message.conversation.other_participant(message.sender_id)
  end

  def read_by_others?
    return false if other_participant.blank?

    other_participant.last_read_message_id.to_i >= message.id
  end
end
