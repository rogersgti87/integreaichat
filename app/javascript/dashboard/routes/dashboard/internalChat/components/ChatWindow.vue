<script setup>
import { computed, nextTick, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  conversation: { type: Object, required: true },
  messages: { type: Array, default: () => [] },
  typingUsers: { type: Array, default: () => [] },
  currentUserId: { type: Number, required: true },
  sending: { type: Boolean, default: false },
});

const emit = defineEmits(['send', 'typing']);
const { t } = useI18n();

const draft = ref('');
const fileInput = ref(null);
const selectedFiles = ref([]);
const messagesEl = ref(null);
let typingTimeout = null;

const typingLabel = computed(() => {
  if (!props.typingUsers.length) return '';
  if (props.typingUsers.length === 1) {
    return t('INTERNAL_CHAT.TYPING', { name: props.typingUsers[0].userName });
  }
  return t('INTERNAL_CHAT.TYPING_SEVERAL');
});

const statusLabel = computed(() => {
  const other = props.conversation.participants?.find(
    p => p.user_id !== props.currentUserId
  );
  if (!other) return '';
  return other.availability_status === 'offline'
    ? t('INTERNAL_CHAT.OFFLINE')
    : t('INTERNAL_CHAT.ONLINE');
});

const roleLabel = computed(() => {
  const other = props.conversation.participants?.find(
    p => p.user_id !== props.currentUserId
  );
  if (!other?.role) return '';
  return other.role === 'administrator'
    ? t('INTERNAL_CHAT.ROLE_ADMINISTRATOR')
    : t('INTERNAL_CHAT.ROLE_AGENT');
});

const scrollToBottom = async () => {
  await nextTick();
  if (messagesEl.value) {
    messagesEl.value.scrollTop = messagesEl.value.scrollHeight;
  }
};

watch(
  () => props.messages.length,
  () => scrollToBottom(),
  { immediate: true }
);

const onInput = () => {
  emit('typing', true);
  clearTimeout(typingTimeout);
  typingTimeout = setTimeout(() => emit('typing', false), 1500);
};

const onPickFiles = event => {
  selectedFiles.value = Array.from(event.target.files || []);
};

const removeFile = index => {
  selectedFiles.value.splice(index, 1);
};

const send = () => {
  const content = draft.value.trim();
  if (!content && !selectedFiles.value.length) return;
  emit('send', { content, attachments: [...selectedFiles.value] });
  draft.value = '';
  selectedFiles.value = [];
  if (fileInput.value) fileInput.value.value = '';
  emit('typing', false);
};

const formatMessageTime = createdAt => {
  const date = new Date(createdAt * 1000);
  return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
};

const statusIcon = status => {
  if (status === 'read') return '✓✓';
  if (status === 'delivered') return '✓✓';
  return '✓';
};
</script>

<template>
  <section class="flex h-full min-h-0 flex-col bg-n-background">
    <header
      class="flex items-center gap-3 border-b border-n-weak bg-n-solid-1 px-4 py-3"
    >
      <img
        v-if="conversation.display_avatar_url"
        :src="conversation.display_avatar_url"
        class="size-10 rounded-full object-cover"
        alt=""
      />
      <div
        v-else
        class="flex size-10 items-center justify-center rounded-full bg-n-brand/15 font-semibold text-n-brand"
      >
        {{ (conversation.display_name || '?').charAt(0).toUpperCase() }}
      </div>
      <div class="min-w-0">
        <h2 class="truncate text-sm font-semibold text-n-slate-12">
          {{ conversation.display_name }}
        </h2>
        <p class="truncate text-xs text-n-slate-10">
          <span
            class="mr-1 inline-block size-2 rounded-full"
            :class="
              statusLabel === t('INTERNAL_CHAT.ONLINE')
                ? 'bg-green-500'
                : 'bg-n-slate-8'
            "
          />
          {{ statusLabel }}
          <span v-if="roleLabel"> · {{ roleLabel }}</span>
        </p>
      </div>
    </header>

    <div ref="messagesEl" class="flex-1 space-y-2 overflow-y-auto px-4 py-4">
      <div
        v-for="message in messages"
        :key="message.id"
        class="flex"
        :class="
          message.sender_id === currentUserId ? 'justify-end' : 'justify-start'
        "
      >
        <div
          class="max-w-[75%] rounded-2xl px-3 py-2 shadow-sm"
          :class="
            message.sender_id === currentUserId
              ? 'rounded-br-md bg-n-brand text-white'
              : 'rounded-bl-md bg-n-solid-1 text-n-slate-12'
          "
        >
          <p
            v-if="message.content"
            class="whitespace-pre-wrap break-words text-sm"
          >
            {{ message.content }}
          </p>
          <div
            v-for="attachment in message.attachments || []"
            :key="attachment.id"
            class="mt-1"
          >
            <a
              :href="attachment.file_url"
              target="_blank"
              rel="noopener"
              class="inline-flex items-center gap-1 text-xs underline"
              :class="
                message.sender_id === currentUserId
                  ? 'text-white/90'
                  : 'text-n-brand'
              "
            >
              <span class="i-lucide-paperclip" />
              {{ attachment.filename }}
            </a>
          </div>
          <div
            class="mt-1 flex items-center justify-end gap-1 text-[10px] opacity-80"
          >
            <span>{{ formatMessageTime(message.created_at) }}</span>
            <span
              v-if="message.sender_id === currentUserId"
              :class="message.status === 'read' ? 'text-sky-200' : ''"
            >
              {{ statusIcon(message.status) }}
            </span>
          </div>
        </div>
      </div>
      <p v-if="typingLabel" class="px-2 text-xs italic text-n-slate-10">
        {{ typingLabel }}
      </p>
    </div>

    <footer class="border-t border-n-weak bg-n-solid-1 p-3">
      <div
        v-if="selectedFiles.length"
        class="mb-2 flex flex-wrap gap-2"
      >
        <span
          v-for="(file, index) in selectedFiles"
          :key="`${file.name}-${index}`"
          class="inline-flex items-center gap-1 rounded-full bg-n-alpha-2 px-2 py-1 text-xs"
        >
          {{ file.name }}
          <button type="button" @click="removeFile(index)">
            <span class="i-lucide-x" />
          </button>
        </span>
      </div>
      <div class="flex items-end gap-2">
        <input
          ref="fileInput"
          type="file"
          class="hidden"
          multiple
          accept=".jpg,.jpeg,.png,.gif,.webp,.pdf,.doc,.docx,.xls,.xlsx,.zip,image/*,application/pdf,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document,application/vnd.ms-excel,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,application/zip"
          @change="onPickFiles"
        />
        <button
          type="button"
          class="inline-flex size-10 items-center justify-center rounded-lg text-n-slate-11 hover:bg-n-alpha-2"
          :title="t('INTERNAL_CHAT.ATTACH')"
          @click="fileInput?.click()"
        >
          <span class="i-lucide-paperclip text-lg" />
        </button>
        <textarea
          v-model="draft"
          rows="1"
          class="max-h-32 min-h-[40px] flex-1 resize-none rounded-xl border-0 bg-n-alpha-2 px-3 py-2 text-sm text-n-slate-12 outline-none placeholder:text-n-slate-9"
          :placeholder="t('INTERNAL_CHAT.TYPE_MESSAGE')"
          @input="onInput"
          @keydown.enter.exact.prevent="send"
        />
        <button
          type="button"
          class="inline-flex h-10 items-center gap-1 rounded-xl bg-n-brand px-4 text-sm font-medium text-white disabled:opacity-50"
          :disabled="sending || (!draft.trim() && !selectedFiles.length)"
          @click="send"
        >
          {{ t('INTERNAL_CHAT.SEND') }}
        </button>
      </div>
    </footer>
  </section>
</template>
