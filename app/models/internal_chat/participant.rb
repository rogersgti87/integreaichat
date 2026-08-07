# frozen_string_literal: true

class InternalChat::Participant < ApplicationRecord
  self.table_name = 'internal_conversation_participants'

  belongs_to :account
  belongs_to :conversation, class_name: 'InternalChat::Conversation'
  belongs_to :user
  belongs_to :last_read_message, class_name: 'InternalChat::Message', optional: true

  validates :account_id, :conversation_id, :user_id, presence: true
  validates :user_id, uniqueness: { scope: [:account_id, :conversation_id] }
  validate :user_belongs_to_account

  scope :for_account, ->(account_id) { where(account_id: account_id) }

  private

  def user_belongs_to_account
    return if account_id.blank? || user_id.blank?
    return if AccountUser.exists?(account_id: account_id, user_id: user_id)

    errors.add(:user_id, 'must belong to the same account')
  end
end
