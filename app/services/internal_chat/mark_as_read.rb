# frozen_string_literal: true

class InternalChat::MarkAsRead
  pattr_initialize [:account!, :conversation!, :user!, :message_id]

  def perform
    raise Pundit::NotAuthorizedError unless conversation.account_id == account.id && conversation.participant?(user.id)

    participant = conversation.participants.find_by!(account_id: account.id, user_id: user.id)
    target_message_id = resolve_message_id

    return participant if participant.last_read_message_id.to_i >= target_message_id.to_i

    participant.update!(last_read_message_id: target_message_id)

    InternalChat::Broadcast.to_participants(
      conversation,
      InternalChat::Broadcast::EVENTS[:message_read],
      {
        user_id: user.id,
        last_read_message_id: target_message_id
      },
      except_user_id: user.id
    )

    participant
  end

  private

  def resolve_message_id
    return message_id.to_i if message_id.present?

    conversation.messages.for_account(account.id).active.maximum(:id) || 0
  end
end
