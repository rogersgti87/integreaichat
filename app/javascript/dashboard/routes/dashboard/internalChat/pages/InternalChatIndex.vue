<script setup>
import { computed, onMounted, onUnmounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useInternalChatStore } from 'dashboard/stores/internalChat';
import ConversationList from '../components/ConversationList.vue';
import ChatWindow from '../components/ChatWindow.vue';
import NewChatModal from '../components/NewChatModal.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useInternalChatStore();
const currentUserId = useMapGetter('getCurrentUserID');

const showNewChat = ref(false);

const activeConversation = computed(() => store.activeConversation);

onMounted(async () => {
  await Promise.all([store.fetchConversations(), store.fetchUnreadCount()]);
  const conversationId = Number(route.params.conversationId);
  if (conversationId) {
    await store.selectConversation(conversationId);
  }
});

watch(
  () => route.params.conversationId,
  async conversationId => {
    if (conversationId) {
      await store.selectConversation(Number(conversationId));
    } else {
      store.activeConversationId = null;
    }
  }
);

const openConversation = conversation => {
  if (conversation?.user && !conversation?.id) {
    startChatWithUser(conversation.user);
    return;
  }
  router.push({
    name: 'internal_chat_conversation',
    params: {
      accountId: route.params.accountId,
      conversationId: conversation.id,
    },
  });
};

const startChatWithUser = async user => {
  showNewChat.value = false;
  const conversation = await store.createConversation([user.id], 'private');
  openConversation(conversation);
};

onUnmounted(() => {
  store.activeConversationId = null;
});
</script>

<template>
  <div class="flex h-full w-full overflow-hidden bg-n-background">
    <ConversationList
      class="w-full max-w-[360px] border-r border-n-weak"
      :conversations="store.conversations"
      :active-id="store.activeConversationId"
      :loading="store.uiFlags.fetchingConversations"
      :search-query="store.searchQuery"
      :search-results="store.searchResults"
      @select="openConversation"
      @search="store.search"
      @new-chat="showNewChat = true"
    />

    <div class="flex min-w-0 flex-1 flex-col">
      <ChatWindow
        v-if="activeConversation"
        :conversation="activeConversation"
        :messages="store.activeMessages"
        :typing-users="store.typingUsersForActive"
        :current-user-id="currentUserId"
        :sending="store.uiFlags.sendingMessage"
        @send="store.sendMessage"
        @typing="store.notifyTyping"
      />
      <div
        v-else
        class="flex h-full flex-col items-center justify-center gap-2 text-n-slate-11"
      >
        <span class="i-lucide-messages-square text-4xl text-n-slate-9" />
        <p class="text-sm">{{ t('INTERNAL_CHAT.EMPTY_STATE') }}</p>
      </div>
    </div>

    <NewChatModal
      v-if="showNewChat"
      :users="store.users"
      :loading="store.uiFlags.fetchingUsers"
      @close="showNewChat = false"
      @search="store.fetchUsers"
      @select="startChatWithUser"
      @open="store.fetchUsers()"
    />
  </div>
</template>
