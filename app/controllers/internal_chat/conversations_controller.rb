# frozen_string_literal: true

class InternalChat::ConversationsController < InternalChat::BaseController
  before_action :find_participating_conversation!, only: [:show, :mark_as_read]

  def index
    conversations = if params[:q].present?
                      InternalChat::SearchConversation.new(
                        account: Current.account,
                        user: Current.user,
                        query: params[:q]
                      ).perform
                    else
                      InternalChat::Conversation.for_user(Current.account.id, Current.user.id).ordered
                    end

    conversations = conversations.includes(participants: :user).page(params[:page]).per(params[:per_page] || 30)

    render json: {
      payload: conversations.map { |c| InternalChat::ConversationPresenter.new(c, current_user: Current.user).as_json },
      meta: {
        page: conversations.current_page,
        total_pages: conversations.total_pages,
        total_count: conversations.total_count
      }
    }
  end

  def show
    render json: {
      payload: InternalChat::ConversationPresenter.new(@conversation, current_user: Current.user).as_json
    }
  end

  def create
    conversation = InternalChat::CreateConversation.new(
      account: Current.account,
      created_by: Current.user,
      participant_ids: conversation_params[:participant_ids],
      conversation_type: conversation_params[:conversation_type].presence || 'private'
    ).perform

    render json: {
      payload: InternalChat::ConversationPresenter.new(conversation, current_user: Current.user).as_json
    }
  rescue InternalChat::Error => e
    render_internal_chat_error(e)
  end

  def mark_as_read
    InternalChat::MarkAsRead.new(
      account: Current.account,
      conversation: @conversation,
      user: Current.user,
      message_id: params[:message_id]
    ).perform

    head :ok
  end

  def unread_count
    count = InternalChat::Conversation.for_user(Current.account.id, Current.user.id).sum do |conversation|
      conversation.unread_count_for(Current.user.id)
    end

    render json: { unread_count: count }
  end

  private

  def conversation_params
    params.require(:conversation).permit(:conversation_type, participant_ids: [])
  end
end
