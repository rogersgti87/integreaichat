/* global axios */
/* Internal Chat API client — account-scoped, decoupled from inbox APIs */
import ApiClient from './ApiClient';

class InternalChatAPI extends ApiClient {
  constructor() {
    super('internal_chat', { accountScoped: true });
  }

  getConversations(params = {}) {
    return axios.get(`${this.url}/conversations`, { params });
  }

  getConversation(id) {
    return axios.get(`${this.url}/conversations/${id}`);
  }

  createConversation(data) {
    return axios.post(`${this.url}/conversations`, { conversation: data });
  }

  getMessages(conversationId, params = {}) {
    return axios.get(`${this.url}/conversations/${conversationId}/messages`, {
      params,
    });
  }

  sendMessage(conversationId, { content, attachments = [] }) {
    const formData = new FormData();
    if (content) formData.append('content', content);
    attachments.forEach(file => {
      formData.append('attachments[]', file);
    });

    return axios.post(
      `${this.url}/conversations/${conversationId}/messages`,
      formData,
      { headers: { 'Content-Type': 'multipart/form-data' } }
    );
  }

  markAsRead(conversationId, messageId) {
    return axios.post(
      `${this.url}/conversations/${conversationId}/mark_as_read`,
      { message_id: messageId }
    );
  }

  typing(conversationId, isTyping = true) {
    return axios.post(
      `${this.url}/conversations/${conversationId}/messages/typing`,
      { typing: isTyping }
    );
  }

  getUsers(params = {}) {
    return axios.get(`${this.url}/users`, { params });
  }

  search(q) {
    return axios.get(`${this.url}/search`, { params: { q } });
  }

  getUnreadCount() {
    return axios.get(`${this.url}/conversations/unread_count`);
  }
}

export default new InternalChatAPI();
