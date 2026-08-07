import { frontendURL } from '../../../helper/URLHelper';
import InternalChatIndex from './pages/InternalChatIndex.vue';

const meta = {
  permissions: ['administrator', 'agent', 'custom_role'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/internal-chat'),
    name: 'internal_chat_index',
    meta,
    component: InternalChatIndex,
  },
  {
    path: frontendURL('accounts/:accountId/internal-chat/:conversationId'),
    name: 'internal_chat_conversation',
    meta,
    component: InternalChatIndex,
  },
];

export default { routes };
