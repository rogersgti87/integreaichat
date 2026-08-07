import { defineStore } from 'pinia';
import InternalChatAPI from 'dashboard/api/internalChat';
import { useAlert } from 'dashboard/composables';
import { emitter } from 'shared/helpers/mitt';

const playNotificationSound = () => {
  try {
    const audio = new Audio('/audio/dashboard/ding.mp3');
    audio.volume = 0.4;
    audio.play().catch(() => {});
  } catch {
    // ignore autoplay restrictions
  }
};

export const useInternalChatStore = defineStore('internalChat', {
  state: () => ({
    conversations: [],
    messages: {},
    users: [],
    activeConversationId: null,
    unreadCount: 0,
    typingUsers: {},
    searchQuery: '',
    searchResults: { conversations: [], users: [] },
    uiFlags: {
      fetchingConversations: false,
      fetchingMessages: false,
      fetchingUsers: false,
      sendingMessage: false,
      creatingConversation: false,
      searching: false,
    },
  }),

  getters: {
    activeConversation(state) {
      return (
        state.conversations.find(c => c.id === state.activeConversationId) ||
        null
      );
    },
    activeMessages(state) {
      if (!state.activeConversationId) return [];
      return state.messages[state.activeConversationId] || [];
    },
    typingUsersForActive(state) {
      return state.typingUsers[state.activeConversationId] || [];
    },
  },

  actions: {
    async fetchConversations(params = {}) {
      this.uiFlags.fetchingConversations = true;
      try {
        const { data } = await InternalChatAPI.getConversations(params);
        this.conversations = data.payload || [];
      } finally {
        this.uiFlags.fetchingConversations = false;
      }
    },

    async fetchUnreadCount() {
      try {
        const { data } = await InternalChatAPI.getUnreadCount();
        this.unreadCount = data.unread_count || 0;
      } catch {
        this.unreadCount = 0;
      }
    },

    async fetchUsers(q = '') {
      this.uiFlags.fetchingUsers = true;
      try {
        const { data } = await InternalChatAPI.getUsers({ q });
        this.users = data.payload || [];
      } finally {
        this.uiFlags.fetchingUsers = false;
      }
    },

    async search(q) {
      this.searchQuery = q;
      if (!q || q.trim().length < 2) {
        this.searchResults = { conversations: [], users: [] };
        return;
      }
      this.uiFlags.searching = true;
      try {
        const { data } = await InternalChatAPI.search(q);
        this.searchResults = data.payload || { conversations: [], users: [] };
      } finally {
        this.uiFlags.searching = false;
      }
    },

    async selectConversation(conversationId) {
      this.activeConversationId = conversationId;
      await this.fetchMessages(conversationId);
      const messages = this.messages[conversationId] || [];
      const lastMessage = messages[messages.length - 1];
      if (lastMessage) {
        await this.markAsRead(conversationId, lastMessage.id);
      }
    },

    async fetchMessages(conversationId, params = {}) {
      this.uiFlags.fetchingMessages = true;
      try {
        const { data } = await InternalChatAPI.getMessages(
          conversationId,
          params
        );
        const payload = data.payload || [];
        if (params.before_id) {
          this.messages[conversationId] = [
            ...payload,
            ...(this.messages[conversationId] || []),
          ];
        } else {
          this.messages[conversationId] = payload;
        }
      } finally {
        this.uiFlags.fetchingMessages = false;
      }
    },

    async createConversation(participantIds, conversationType = 'private') {
      this.uiFlags.creatingConversation = true;
      try {
        const { data } = await InternalChatAPI.createConversation({
          participant_ids: participantIds,
          conversation_type: conversationType,
        });
        const conversation = data.payload;
        this.upsertConversation(conversation);
        await this.selectConversation(conversation.id);
        return conversation;
      } catch (error) {
        useAlert(
          error?.response?.data?.error || 'Não foi possível criar a conversa'
        );
        throw error;
      } finally {
        this.uiFlags.creatingConversation = false;
      }
    },

    async sendMessage({ content, attachments = [] }) {
      if (!this.activeConversationId) return;
      if (!content?.trim() && !attachments.length) return;

      this.uiFlags.sendingMessage = true;
      try {
        const { data } = await InternalChatAPI.sendMessage(
          this.activeConversationId,
          { content, attachments }
        );
        this.appendMessage(data.payload);
        this.upsertConversation({
          ...this.activeConversation,
          last_message: {
            id: data.payload.id,
            content: data.payload.content,
            sender_id: data.payload.sender_id,
            message_type: data.payload.message_type,
            created_at: data.payload.created_at,
          },
          last_message_at: data.payload.created_at,
          unread_count: 0,
        });
      } catch (error) {
        useAlert(
          error?.response?.data?.error || 'Não foi possível enviar a mensagem'
        );
      } finally {
        this.uiFlags.sendingMessage = false;
      }
    },

    async markAsRead(conversationId, messageId) {
      try {
        await InternalChatAPI.markAsRead(conversationId, messageId);
        const conversation = this.conversations.find(
          c => c.id === conversationId
        );
        if (conversation) {
          const previousUnread = conversation.unread_count || 0;
          conversation.unread_count = 0;
          this.unreadCount = Math.max(0, this.unreadCount - previousUnread);
        }
      } catch {
        // ignore
      }
    },

    async notifyTyping(isTyping = true) {
      if (!this.activeConversationId) return;
      try {
        await InternalChatAPI.typing(this.activeConversationId, isTyping);
      } catch {
        // ignore
      }
    },

    upsertConversation(conversation) {
      if (!conversation?.id) return;
      const index = this.conversations.findIndex(c => c.id === conversation.id);
      if (index === -1) {
        this.conversations.unshift(conversation);
      } else {
        this.conversations.splice(index, 1, {
          ...this.conversations[index],
          ...conversation,
        });
      }
      this.conversations.sort((a, b) => {
        const aTime = a.last_message_at || a.created_at || 0;
        const bTime = b.last_message_at || b.created_at || 0;
        const aMs = aTime > 1e12 ? aTime : aTime * 1000;
        const bMs = bTime > 1e12 ? bTime : bTime * 1000;
        return bMs - aMs;
      });
    },

    appendMessage(message) {
      if (!message?.conversation_id) return;
      const list = this.messages[message.conversation_id] || [];
      if (list.some(m => m.id === message.id)) return;
      this.messages[message.conversation_id] = [...list, message];
    },

    handleRealtimeMessage(message, currentUserId) {
      this.appendMessage(message);
      const isOwn = message.sender_id === currentUserId;
      const conversation = this.conversations.find(
        c => c.id === message.conversation_id
      );

      if (conversation) {
        this.upsertConversation({
          ...conversation,
          last_message: {
            id: message.id,
            content: message.content,
            sender_id: message.sender_id,
            message_type: message.message_type,
            created_at: message.created_at,
          },
          last_message_at: message.created_at,
          unread_count:
            !isOwn && this.activeConversationId !== message.conversation_id
              ? (conversation.unread_count || 0) + 1
              : conversation.unread_count || 0,
        });
      } else {
        this.fetchConversations();
      }

      if (!isOwn) {
        if (this.activeConversationId !== message.conversation_id) {
          this.unreadCount += 1;
          playNotificationSound();
          useAlert(
            `${message.sender?.available_name || message.sender?.name}: ${message.content || 'Anexo'}`
          );
        } else {
          this.markAsRead(message.conversation_id, message.id);
        }
        emitter.emit('internalChat:message', message);
      }
    },

    handleMessageRead({ conversation_id: conversationId, user_id: userId, last_read_message_id: lastReadMessageId }) {
      const list = this.messages[conversationId] || [];
      this.messages[conversationId] = list.map(message => {
        if (message.sender_id !== userId && message.id <= lastReadMessageId) {
          return { ...message, status: 'read' };
        }
        return message;
      });
    },

    handleTyping({ conversation_id: conversationId, user_id: userId, user_name: userName, typing }) {
      const current = this.typingUsers[conversationId] || [];
      if (typing === false) {
        this.typingUsers[conversationId] = current.filter(u => u.userId !== userId);
        return;
      }
      if (!current.some(u => u.userId === userId)) {
        this.typingUsers[conversationId] = [
          ...current,
          { userId, userName },
        ];
      }
    },

    handleConversationCreated(conversation) {
      this.upsertConversation(conversation);
    },
  },
});
