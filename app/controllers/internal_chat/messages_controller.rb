# frozen_string_literal: true

class InternalChat::MessagesController < InternalChat::BaseController
  before_action :find_participating_conversation!

  def index
    messages = @conversation.messages
                            .for_account(Current.account.id)
                            .active
                            .includes(:sender, attachments: { file_attachment: :blob })
                            .chronological

    if params[:before_id].present?
      messages = messages.where('id < ?', params[:before_id].to_i)
    end

    messages = messages.reorder(created_at: :desc, id: :desc).limit((params[:per_page] || 50).to_i).to_a.reverse

    render json: {
      payload: messages.map { |message| InternalChat::MessagePresenter.new(message, viewer: Current.user).as_json }
    }
  end

  def create
    message = InternalChat::SendMessage.new(
      account: Current.account,
      conversation: @conversation,
      sender: Current.user,
      content: params[:content],
      files: params[:attachments]
    ).perform

    render json: {
      payload: InternalChat::MessagePresenter.new(message, viewer: Current.user).as_json
    }
  rescue InternalChat::Error => e
    render_internal_chat_error(e)
  end

  def typing
    event = params[:typing] == false || params[:typing] == 'false' ? :typing_off : :typing_on

    InternalChat::Broadcast.to_participants(
      @conversation,
      InternalChat::Broadcast::EVENTS[event],
      {
        user_id: Current.user.id,
        user_name: Current.user.available_name.presence || Current.user.name
      },
      except_user_id: Current.user.id
    )

    head :ok
  end
end
