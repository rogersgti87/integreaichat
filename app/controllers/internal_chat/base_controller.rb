# frozen_string_literal: true

class InternalChat::BaseController < Api::V1::Accounts::BaseController
  before_action :ensure_agent_or_admin!

  private

  def ensure_agent_or_admin!
    # Any account member (agent/admin) can use Internal Chat.
    # Account membership is already validated by Api::V1::Accounts::BaseController.
    return if Current.account_user.present?

    render json: { error: 'Access denied' }, status: :forbidden
  end

  def render_internal_chat_error(error)
    render json: { error: error.message }, status: :unprocessable_entity
  end

  def find_participating_conversation!
    @conversation = InternalChat::Conversation
                    .for_user(Current.account.id, Current.user.id)
                    .find_by(id: params[:conversation_id] || params[:id])

    raise ActiveRecord::RecordNotFound if @conversation.blank?
  end
end
