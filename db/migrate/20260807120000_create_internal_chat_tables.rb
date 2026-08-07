class CreateInternalChatTables < ActiveRecord::Migration[7.1]
  def change
    create_table :internal_conversations do |t|
      t.references :account, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :conversation_type, null: false, default: 'private'
      t.datetime :last_message_at
      t.timestamps
    end

    add_index :internal_conversations, [:account_id, :last_message_at]
    add_index :internal_conversations, [:account_id, :conversation_type]

    create_table :internal_conversation_participants do |t|
      t.references :account, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: { to_table: :internal_conversations }
      t.references :user, null: false, foreign_key: true
      t.bigint :last_read_message_id
      t.datetime :joined_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.timestamps
    end

    add_index :internal_conversation_participants,
              [:account_id, :conversation_id, :user_id],
              unique: true,
              name: 'idx_internal_participants_account_conversation_user'
    add_index :internal_conversation_participants, [:account_id, :user_id]

    create_table :internal_messages do |t|
      t.references :account, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: { to_table: :internal_conversations }
      t.references :sender, null: false, foreign_key: { to_table: :users }
      t.text :content, null: false, default: ''
      t.string :message_type, null: false, default: 'text'
      t.bigint :reply_to_id
      t.datetime :edited_at
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :internal_messages,
              [:account_id, :conversation_id, :created_at],
              name: 'idx_internal_messages_account_conversation_created'
    add_index :internal_messages, [:account_id, :sender_id]
    add_index :internal_messages, :reply_to_id

    create_table :internal_message_attachments do |t|
      t.references :account, null: false, foreign_key: true
      t.references :message, null: false, foreign_key: { to_table: :internal_messages }
      t.timestamps
    end

    add_index :internal_message_attachments, [:account_id, :message_id]
  end
end
