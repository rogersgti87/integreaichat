# frozen_string_literal: true

class InternalChat::MessageAttachment < ApplicationRecord
  self.table_name = 'internal_message_attachments'

  belongs_to :account
  belongs_to :message, class_name: 'InternalChat::Message'
  has_one_attached :file

  validates :account_id, :message_id, presence: true
  validate :acceptable_file

  scope :for_account, ->(account_id) { where(account_id: account_id) }

  def push_event_data
    return {} unless file.attached?

    {
      id: id,
      file_url: Rails.application.routes.url_helpers.rails_blob_url(file, only_path: true),
      filename: file.filename.to_s,
      content_type: file.content_type,
      byte_size: file.byte_size
    }
  end

  private

  def acceptable_file
    return unless file.attached?

    unless InternalChat::Message::ALLOWED_CONTENT_TYPES.include?(file.content_type)
      errors.add(:file, 'type is not allowed')
    end

    return if file.byte_size <= 20.megabytes

    errors.add(:file, 'is too large (max 20MB)')
  end
end
