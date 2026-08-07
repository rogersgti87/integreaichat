# frozen_string_literal: true

class InternalChat::Message < ApplicationRecord
  self.table_name = 'internal_messages'

  MESSAGE_TYPES = %w[text attachment system].freeze
  ALLOWED_CONTENT_TYPES = %w[
    image/jpeg image/png image/gif image/webp
    application/pdf
    application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/vnd.ms-excel
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    application/zip
    application/x-zip-compressed
  ].freeze

  belongs_to :account
  belongs_to :conversation, class_name: 'InternalChat::Conversation'
  belongs_to :sender, class_name: 'User'
  belongs_to :reply_to, class_name: 'InternalChat::Message', optional: true
  has_many :attachments,
           class_name: 'InternalChat::MessageAttachment',
           foreign_key: :message_id,
           dependent: :destroy,
           inverse_of: :message

  validates :account_id, :conversation_id, :sender_id, presence: true
  validates :message_type, inclusion: { in: MESSAGE_TYPES }
  validates :content, presence: true, unless: -> { attachments.any? || message_type == 'attachment' }

  scope :for_account, ->(account_id) { where(account_id: account_id) }
  scope :active, -> { where(deleted_at: nil) }
  scope :chronological, -> { order(created_at: :asc, id: :asc) }

  def soft_delete!
    update!(deleted_at: Time.current, content: '')
  end
end
