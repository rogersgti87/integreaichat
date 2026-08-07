<script setup>
import { onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  conversations: { type: Array, default: () => [] },
  users: { type: Array, default: () => [] },
  activeId: { type: Number, default: null },
  loading: { type: Boolean, default: false },
  searchQuery: { type: String, default: '' },
  searchResults: {
    type: Object,
    default: () => ({ conversations: [], users: [] }),
  },
});

const emit = defineEmits(['select', 'search', 'new-chat']);
const { t } = useI18n();
const query = ref(props.searchQuery);

watch(query, value => {
  emit('search', value);
});

onMounted(() => {
  query.value = props.searchQuery;
});

const previewText = conversation => {
  const last = conversation.last_message;
  if (!last) return '';
  if (last.message_type === 'attachment') return '📎 Anexo';
  return last.content || '';
};

const formatTime = conversation => {
  const raw = conversation.last_message_at || conversation.created_at;
  if (!raw) return '';
  const date =
    typeof raw === 'number'
      ? new Date(raw > 1e12 ? raw : raw * 1000)
      : new Date(raw);
  return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
};

const roleLabel = role => {
  if (role === 'administrator') return t('INTERNAL_CHAT.ROLE_ADMINISTRATOR');
  if (role === 'agent') return t('INTERNAL_CHAT.ROLE_AGENT');
  return role || '';
};

const statusLabel = user =>
  user.availability_status === 'offline'
    ? t('INTERNAL_CHAT.OFFLINE')
    : t('INTERNAL_CHAT.ONLINE');
</script>

<template>
  <aside class="flex h-full flex-col bg-n-solid-1">
    <div class="flex items-center gap-2 border-b border-n-weak p-3">
      <div class="relative flex-1">
        <span
          class="i-lucide-search absolute left-3 top-1/2 -translate-y-1/2 text-n-slate-10"
        />
        <input
          v-model="query"
          type="search"
          class="w-full rounded-lg border-0 bg-n-alpha-2 py-2 pl-9 pr-3 text-sm text-n-slate-12 outline-none placeholder:text-n-slate-9"
          :placeholder="t('INTERNAL_CHAT.SEARCH_PLACEHOLDER')"
        />
      </div>
      <button
        type="button"
        class="inline-flex size-9 items-center justify-center rounded-lg bg-n-brand text-white hover:opacity-90"
        :title="t('INTERNAL_CHAT.NEW_CHAT')"
        @click="emit('new-chat')"
      >
        <span class="i-lucide-plus text-lg" />
      </button>
    </div>

    <div class="flex-1 overflow-y-auto">
      <div
        v-if="loading"
        class="p-4 text-center text-sm text-n-slate-10"
      >
        ...
      </div>

      <template v-else-if="query.trim().length >= 2">
        <div
          v-if="!searchResults.conversations?.length && !searchResults.users?.length"
          class="p-4 text-center text-sm text-n-slate-10"
        >
          {{ t('INTERNAL_CHAT.NO_RESULTS') }}
        </div>

        <div v-if="searchResults.users?.length" class="px-3 pt-3">
          <p class="mb-2 text-xs font-semibold uppercase text-n-slate-10">
            {{ t('INTERNAL_CHAT.USERS') }}
          </p>
          <button
            v-for="user in searchResults.users"
            :key="`user-${user.id}`"
            type="button"
            class="mb-1 flex w-full items-center gap-3 rounded-lg px-2 py-2 text-left hover:bg-n-alpha-2"
            @click="$emit('select', { id: null, user })"
          >
            <img
              v-if="user.avatar_url"
              :src="user.avatar_url"
              class="size-10 rounded-full object-cover"
              alt=""
            />
            <div
              v-else
              class="flex size-10 items-center justify-center rounded-full bg-n-alpha-2 text-sm font-medium"
            >
              {{ (user.name || '?').charAt(0).toUpperCase() }}
            </div>
            <div class="min-w-0">
              <p class="truncate text-sm font-medium text-n-slate-12">
                {{ user.available_name || user.name }}
              </p>
              <p class="truncate text-xs text-n-slate-10">
                {{ roleLabel(user.role) }} · {{ statusLabel(user) }}
              </p>
            </div>
          </button>
        </div>

        <div v-if="searchResults.conversations?.length" class="px-3 pt-3">
          <p class="mb-2 text-xs font-semibold uppercase text-n-slate-10">
            {{ t('INTERNAL_CHAT.CONVERSATIONS') }}
          </p>
          <button
            v-for="conversation in searchResults.conversations"
            :key="`search-c-${conversation.id}`"
            type="button"
            class="mb-1 flex w-full items-center gap-3 rounded-lg px-2 py-2 text-left hover:bg-n-alpha-2"
            :class="{ 'bg-n-alpha-2': conversation.id === activeId }"
            @click="$emit('select', conversation)"
          >
            <div class="min-w-0 flex-1">
              <p class="truncate text-sm font-medium text-n-slate-12">
                {{ conversation.display_name }}
              </p>
              <p class="truncate text-xs text-n-slate-10">
                {{ previewText(conversation) }}
              </p>
            </div>
          </button>
        </div>
      </template>

      <template v-else>
        <div v-if="conversations.length" class="px-3 pt-3">
          <p class="mb-2 text-xs font-semibold uppercase text-n-slate-10">
            {{ t('INTERNAL_CHAT.CONVERSATIONS') }}
          </p>
          <button
            v-for="conversation in conversations"
            :key="conversation.id"
            type="button"
            class="mb-1 flex w-full items-center gap-3 rounded-lg px-2 py-2 text-left hover:bg-n-alpha-2"
            :class="{ 'bg-n-alpha-2': conversation.id === activeId }"
            @click="$emit('select', conversation)"
          >
            <div class="relative shrink-0">
              <img
                v-if="conversation.display_avatar_url"
                :src="conversation.display_avatar_url"
                class="size-11 rounded-full object-cover"
                alt=""
              />
              <div
                v-else
                class="flex size-11 items-center justify-center rounded-full bg-n-brand/15 text-sm font-semibold text-n-brand"
              >
                {{ (conversation.display_name || '?').charAt(0).toUpperCase() }}
              </div>
              <span
                v-if="conversation.unread_count > 0"
                class="absolute -right-1 -top-1 flex min-w-[18px] items-center justify-center rounded-full bg-n-brand px-1 text-[10px] font-bold text-white"
              >
                {{ conversation.unread_count }}
              </span>
            </div>
            <div class="min-w-0 flex-1">
              <div class="flex items-center justify-between gap-2">
                <p class="truncate text-sm font-semibold text-n-slate-12">
                  {{ conversation.display_name }}
                </p>
                <span class="shrink-0 text-[11px] text-n-slate-10">
                  {{ formatTime(conversation) }}
                </span>
              </div>
              <p class="truncate text-xs text-n-slate-10">
                {{ previewText(conversation) }}
              </p>
            </div>
          </button>
        </div>

        <div class="px-3 pt-3 pb-3">
          <p class="mb-2 text-xs font-semibold uppercase text-n-slate-10">
            {{ t('INTERNAL_CHAT.USERS') }}
          </p>
          <p
            v-if="!users.length"
            class="p-4 text-center text-sm text-n-slate-10"
          >
            {{ t('INTERNAL_CHAT.NO_RESULTS') }}
          </p>
          <button
            v-for="user in users"
            :key="`team-user-${user.id}`"
            type="button"
            class="mb-1 flex w-full items-center gap-3 rounded-lg px-2 py-2 text-left hover:bg-n-alpha-2"
            @click="$emit('select', { id: null, user })"
          >
            <div class="relative shrink-0">
              <img
                v-if="user.avatar_url"
                :src="user.avatar_url"
                class="size-11 rounded-full object-cover"
                alt=""
              />
              <div
                v-else
                class="flex size-11 items-center justify-center rounded-full bg-n-alpha-2 text-sm font-medium"
              >
                {{ (user.name || '?').charAt(0).toUpperCase() }}
              </div>
              <span
                class="absolute bottom-0 right-0 size-2.5 rounded-full border-2 border-n-solid-1"
                :class="
                  user.availability_status === 'offline'
                    ? 'bg-n-slate-8'
                    : 'bg-green-500'
                "
              />
            </div>
            <div class="min-w-0 flex-1">
              <p class="truncate text-sm font-semibold text-n-slate-12">
                {{ user.available_name || user.name }}
              </p>
              <p class="truncate text-xs text-n-slate-10">
                {{ roleLabel(user.role) }} · {{ statusLabel(user) }}
              </p>
            </div>
          </button>
        </div>
      </template>
    </div>
  </aside>
</template>
