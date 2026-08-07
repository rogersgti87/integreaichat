# frozen_string_literal: true

class InternalChat::Conversation < ApplicationRecord
  self.table_name = 'internal_conversations'

  CONVERSATION_TYPES = %w[private group].freeze

  belongs_to :account
  belongs_to :created_by, class_name: 'User'
  has_many :participants,
           class_name: 'InternalChat::Participant',
           foreign_key: :conversation_id,
           dependent: :destroy,
           inverse_of: :conversation
  has_many :users, through: :participants
  has_many :messages,
           class_name: 'InternalChat::Message',
           foreign_key: :conversation_id,
           dependent: :destroy,
           inverse_of: :conversation

  validates :conversation_type, inclusion: { in: CONVERSATION_TYPES }
  validates :account_id, presence: true

  scope :for_account, ->(account_id) { where(account_id: account_id) }
  scope :for_user, lambda { |account_id, user_id|
    for_account(account_id)
      .joins(:participants)
      .where(internal_conversation_participants: { account_id: account_id, user_id: user_id })
      .distinct
  }
  scope :ordered, -> { order(Arel.sql('COALESCE(last_message_at, created_at) DESC')) }

  def private?
    conversation_type == 'private'
  end

  def participant?(user_id)
    participants.exists?(account_id: account_id, user_id: user_id)
  end

  def other_participant(user_id)
    participants.where(account_id: account_id).where.not(user_id: user_id).first
  end

  def unread_count_for(user_id)
    participant = participants.find_by(account_id: account_id, user_id: user_id)
    return 0 if participant.blank?

    scope = messages.for_account(account_id).active.where.not(sender_id: user_id)
    scope = scope.where('id > ?', participant.last_read_message_id) if participant.last_read_message_id.present?
    scope.count
  end
end
