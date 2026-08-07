# frozen_string_literal: true

class InternalChat::SearchConversation
  pattr_initialize [:account!, :user!, :query!]

  def perform
    return InternalChat::Conversation.none if query.blank?

    sanitized = "%#{ActiveRecord::Base.sanitize_sql_like(query.strip)}%"

    conversation_ids_from_users = InternalChat::Conversation
                                  .for_user(account.id, user.id)
                                  .joins(participants: :user)
                                  .where('users.name ILIKE :q OR users.email ILIKE :q', q: sanitized)
                                  .pluck(:id)

    conversation_ids_from_messages = InternalChat::Message
                                     .for_account(account.id)
                                     .active
                                     .where('content ILIKE ?', sanitized)
                                     .where(conversation_id: InternalChat::Conversation.for_user(account.id, user.id).select(:id))
                                     .pluck(:conversation_id)

    InternalChat::Conversation
      .for_account(account.id)
      .where(id: (conversation_ids_from_users + conversation_ids_from_messages).uniq)
      .ordered
  end
end
