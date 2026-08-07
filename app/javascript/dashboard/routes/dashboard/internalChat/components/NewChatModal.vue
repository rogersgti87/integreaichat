<script setup>
import { onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  users: { type: Array, default: () => [] },
  loading: { type: Boolean, default: false },
});

const emit = defineEmits(['close', 'search', 'select', 'open']);
const { t } = useI18n();
const query = ref('');

onMounted(() => emit('open'));

watch(query, value => emit('search', value));
</script>

<template>
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
    @click.self="emit('close')"
  >
    <div
      class="flex max-h-[80vh] w-full max-w-md flex-col overflow-hidden rounded-2xl bg-n-solid-1 shadow-xl"
    >
      <div class="flex items-center justify-between border-b border-n-weak px-4 py-3">
        <h3 class="text-sm font-semibold text-n-slate-12">
          {{ t('INTERNAL_CHAT.NEW_CHAT') }}
        </h3>
        <button
          type="button"
          class="rounded-lg p-1 hover:bg-n-alpha-2"
          @click="emit('close')"
        >
          <span class="i-lucide-x" />
        </button>
      </div>

      <div class="p-3">
        <input
          v-model="query"
          type="search"
          class="w-full rounded-lg bg-n-alpha-2 px-3 py-2 text-sm outline-none"
          :placeholder="t('INTERNAL_CHAT.SEARCH_PLACEHOLDER')"
        />
      </div>

      <div class="flex-1 overflow-y-auto px-2 pb-3">
        <div
          v-if="loading"
          class="p-4 text-center text-sm text-n-slate-10"
        >
          ...
        </div>
        <button
          v-for="user in users"
          :key="user.id"
          type="button"
          class="mb-1 flex w-full items-center gap-3 rounded-lg px-3 py-2 text-left hover:bg-n-alpha-2"
          @click="emit('select', user)"
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
          <div class="min-w-0 flex-1">
            <div class="flex items-center gap-2">
              <p class="truncate text-sm font-medium text-n-slate-12">
                {{ user.available_name || user.name }}
              </p>
              <span
                class="size-2 rounded-full"
                :class="
                  user.availability_status === 'offline'
                    ? 'bg-n-slate-8'
                    : 'bg-green-500'
                "
              />
            </div>
            <p class="truncate text-xs text-n-slate-10">
              {{ user.role }} · {{ user.email }}
            </p>
          </div>
        </button>
        <p
          v-if="!loading && !users.length"
          class="p-4 text-center text-sm text-n-slate-10"
        >
          {{ t('INTERNAL_CHAT.NO_RESULTS') }}
        </p>
      </div>
    </div>
  </div>
</template>
