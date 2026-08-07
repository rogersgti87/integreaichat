# frozen_string_literal: true

class InternalChat::SendMessage
  pattr_initialize [:account!, :conversation!, :sender!, :content, :files]

  def perform
    ensure_participant!
    ensure_content!

    message = nil
    ActiveRecord::Base.transaction do
      message = conversation.messages.create!(
        account_id: account.id,
        sender_id: sender.id,
        content: content.to_s,
        message_type: files.present? ? 'attachment' : 'text'
      )

      Array(files).each do |file|
        attachment = message.attachments.create!(account_id: account.id)
        attachment.file.attach(file)
        attachment.save!
      end

      conversation.update!(last_message_at: message.created_at)

      sender_participant = conversation.participants.find_by!(account_id: account.id, user_id: sender.id)
      sender_participant.update!(last_read_message_id: message.id)
    end

    payload = InternalChat::MessagePresenter.new(message.reload, viewer: sender).as_json
    InternalChat::Broadcast.to_participants(
      conversation,
      InternalChat::Broadcast::EVENTS[:message_created],
      payload
    )

    message
  end

  private

  def ensure_participant!
    return if conversation.participant?(sender.id) && conversation.account_id == account.id

    raise Pundit::NotAuthorizedError
  end

  def ensure_content!
    return if content.present? || files.present?

    raise InternalChat::Error, 'Message content or attachment is required'
  end
end
