# frozen_string_literal: true

class InternalChat::CreateConversation
  pattr_initialize [:account!, :created_by!, :participant_ids!, :conversation_type!]

  def perform
    validate_participants!
    return existing_private_conversation if conversation_type == 'private' && existing_private_conversation.present?

    ActiveRecord::Base.transaction do
      conversation = InternalChat::Conversation.create!(
        account_id: account.id,
        created_by_id: created_by.id,
        conversation_type: conversation_type
      )

      unique_participant_ids.each do |user_id|
        conversation.participants.create!(
          account_id: account.id,
          user_id: user_id,
          joined_at: Time.current
        )
      end

      InternalChat::Broadcast.to_participants(
        conversation,
        InternalChat::Broadcast::EVENTS[:conversation_created],
        InternalChat::ConversationPresenter.new(conversation, current_user: created_by).as_json
      )

      conversation
    end
  end

  private

  def unique_participant_ids
    @unique_participant_ids ||= (Array(participant_ids).map(&:to_i) + [created_by.id]).uniq
  end

  def validate_participants!
    raise InternalChat::Error, 'At least two participants are required' if unique_participant_ids.size < 2

    if conversation_type == 'private' && unique_participant_ids.size != 2
      raise InternalChat::Error, 'Private conversations require exactly two participants'
    end

    valid_ids = account.account_users.where(user_id: unique_participant_ids).pluck(:user_id)
    return if valid_ids.sort == unique_participant_ids.sort

    raise InternalChat::Error, 'All participants must belong to the same account'
  end

  def existing_private_conversation
    @existing_private_conversation ||= begin
      other_user_id = unique_participant_ids.find { |id| id != created_by.id }
      candidate_ids = InternalChat::Participant
                      .for_account(account.id)
                      .where(user_id: [created_by.id, other_user_id])
                      .group(:conversation_id)
                      .having('COUNT(DISTINCT user_id) = 2')
                      .pluck(:conversation_id)

      InternalChat::Conversation
        .for_account(account.id)
        .where(id: candidate_ids, conversation_type: 'private')
        .first
    end
  end
end
