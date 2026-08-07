# Internal Chat — Guia de Produção

Este documento descreve como colocar o módulo **Internal Chat** em produção, inclusive em uma instalação Chatwoot que já esteja rodando.

O módulo é **desacoplado** do núcleo de atendimento (Inbox / Conversations / Contacts / Messages). Ele usa apenas:

- autenticação e usuários do Chatwoot
- multi-tenant por `account_id`
- Redis + ActionCable (WebSocket)
- Active Storage (anexos)

---

## 1. Pré-requisitos

- Chatwoot já instalado e saudável (Rails + Sidekiq + Redis + Postgres + assets)
- Acesso SSH ao servidor (ou ao container/host onde roda o app)
- Backup do banco antes de migrar
- Node.js / pnpm disponíveis no pipeline de build de assets (mesmo fluxo que você já usa no Chatwoot)

Não é necessário Docker nem WSL para este módulo.

---

## 2. O que este módulo adiciona

### Banco

Tabelas novas:

| Tabela | Uso |
|---|---|
| `internal_conversations` | Conversas internas (private/group) |
| `internal_conversation_participants` | Participantes + last_read |
| `internal_messages` | Mensagens |
| `internal_message_attachments` | Metadados de anexo (+ Active Storage) |

Todas possuem `account_id` obrigatório (isolamento multiempresa).

### API

Base (account-scoped):

```
/api/v1/accounts/:account_id/internal_chat/...
```

Principais endpoints:

- `GET    /internal_chat/conversations`
- `POST   /internal_chat/conversations`
- `GET    /internal_chat/conversations/:id`
- `POST   /internal_chat/conversations/:id/mark_as_read`
- `GET    /internal_chat/conversations/unread_count`
- `GET    /internal_chat/conversations/:id/messages`
- `POST   /internal_chat/conversations/:id/messages`
- `POST   /internal_chat/conversations/:id/messages/typing`
- `GET    /internal_chat/users`
- `GET    /internal_chat/search`

### Frontend

- Item na sidebar: **Internal Chat**
- Rota: `/app/accounts/:accountId/internal-chat`

### WebSocket

Eventos broadcast via ActionCable (stream do `pubsub_token` do usuário):

- `internal_chat.message.created`
- `internal_chat.conversation.created`
- `internal_chat.message.read`
- `internal_chat.typing.on`
- `internal_chat.typing.off`

---

## 3. Implantar em Chatwoot já em produção

### Passo A — Obter o código

No servidor/repositório de produção, incorpore este fork/branch que contém o Internal Chat (merge ou cherry-pick dos commits do módulo).

Arquivos principais (para conferência):

```
app/models/internal_chat/
app/controllers/internal_chat/
app/services/internal_chat/
app/channels/internal_chat_channel.rb
config/routes/internal_chat.rb
db/migrate/20260807120000_create_internal_chat_tables.rb
app/javascript/dashboard/routes/dashboard/internalChat/
app/javascript/dashboard/stores/internalChat.js
app/javascript/dashboard/api/internalChat.js
docs/Chatinterno.md
docs/internal-chat-producao.md
```

Há alterações pontuais de integração (necessárias para aparecer na UI):

- `config/routes.rb` — `draw :internal_chat`
- `app/javascript/dashboard/routes/dashboard/dashboard.routes.js`
- `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`
- `app/javascript/dashboard/helper/actionCable.js`
- `app/javascript/dashboard/i18n/locale/en/*`

### Passo B — Backup

```bash
# exemplo Postgres
pg_dump -U <user> -h <host> <database> > chatwoot_backup_$(date +%F).sql
```

### Passo C — Dependências

No diretório da aplicação:

```bash
bundle install
pnpm install
```

### Passo D — Migrar o banco

```bash
RAILS_ENV=production bundle exec rails db:migrate
```

Isso cria apenas as tabelas `internal_*`. Não altera tabelas de atendimento.

Confirme:

```bash
RAILS_ENV=production bundle exec rails runner \
  "puts ActiveRecord::Base.connection.table_exists?(:internal_conversations)"
# => true
```

### Passo E — Build de assets

Use o mesmo fluxo já adotado na sua instalação. Exemplos comuns:

```bash
# se a produção compila assets no deploy
RAILS_ENV=production bundle exec rails assets:precompile
# e/ou
pnpm build   # conforme scripts do seu fork
```

Se você usa Vite em runtime só em desenvolvimento, em produção continue com o pipeline oficial do Chatwoot (precompile / imagem de release).

### Passo F — Reiniciar processos

Reinicie **web** (Puma/Unicorn) e **worker** (Sidekiq), e mantenha Redis acessível (ActionCable + jobs).

Exemplos:

```bash
# systemd
sudo systemctl restart chatwoot-web chatwoot-worker

# ou overmind/foreman/hatchbox/etc. — reinicie os processos da app
```

Se ActionCable roda em processo separado (qualquercable / dedicated cable), reinicie-o também.

### Passo G — Validação rápida

1. Login no dashboard com um agente/admin.
2. Sidebar deve exibir **Internal Chat**.
3. Abra o módulo, inicie conversa com outro usuário da **mesma account**.
4. Envie texto e um anexo (pdf/imagem).
5. Confirme badge de não lidas e indicador “digitando”.
6. Em outra account, confirme que usuários/conversas **não** aparecem (isolamento).

Checklist API (substitua token/account):

```bash
curl -H "access-token: ..." -H "client: ..." -H "uid: ..." \
  "https://SEU_DOMINIO/api/v1/accounts/ACCOUNT_ID/internal_chat/conversations"
```

---

## 4. Variáveis de ambiente

O módulo **não exige** variáveis novas.

Reaproveita:

| Variável | Motivo |
|---|---|
| `REDIS_URL` | ActionCable / Sidekiq / presence |
| `FRONTEND_URL` | URLs e cookies |
| `ACTIVE_STORAGE_*` / S3 | Anexos |
| `SECRET_KEY_BASE` | Sessão |

Garanta que WebSocket (`/cable`) está liberado no proxy (Nginx/Traefik) com upgrade de conexão — o Internal Chat usa o mesmo cable do Chatwoot.

Exemplo Nginx (já comum no Chatwoot):

```nginx
location /cable {
  proxy_pass http://chatwoot;
  proxy_http_version 1.1;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection "Upgrade";
  proxy_set_header Host $host;
}
```

---

## 5. Permissões e multiempresa

- Qualquer `administrator` ou `agent` da account pode usar o Internal Chat.
- Conversas e usuários são sempre filtrados por `Current.account.id`.
- Participação é obrigatória para ler/enviar mensagens.
- Não há comunicação entre accounts diferentes.

---

## 6. Anexos (Active Storage)

Tipos aceitos na v1:

- imagens: jpeg, png, gif, webp
- documentos: pdf, doc, docx, xls, xlsx
- zip

Limite: **20 MB** por arquivo.

Em produção com S3/MinIO, nenhuma configuração extra do módulo é necessária além do Active Storage já usado pelo Chatwoot.

---

## 7. Atualizar Chatwoot upstream com o mínimo de conflito

Ao puxar updates do Chatwoot OSS:

1. Reaplique/resolva conflitos apenas nos pontos de integração listados no Passo A.
2. O núcleo do módulo (`app/models|controllers|services/internal_chat`) tende a permanecer intacto.
3. Rode `db:migrate` se houver novas migrations do módulo.
4. Rebuild de assets + restart.

Evite mover código do Internal Chat para models/controllers de Conversation/Message/Inbox.

---

## 8. Rollback

Se precisar desfazer:

1. Remova o item de menu / rotas FE / handlers ActionCable (ou reverta o commit).
2. Reinicie a app.
3. (Opcional) remova tabelas:

```bash
RAILS_ENV=production bundle exec rails runner "
  ActiveRecord::Migration.drop_table(:internal_message_attachments, if_exists: true)
  ActiveRecord::Migration.drop_table(:internal_messages, if_exists: true)
  ActiveRecord::Migration.drop_table(:internal_conversation_participants, if_exists: true)
  ActiveRecord::Migration.drop_table(:internal_conversations, if_exists: true)
"
```

Faça backup antes. Anexos no Active Storage podem precisar limpeza manual dos blobs órfãos.

---

## 9. Desenvolvimento local (Windows, sem Docker/WSL)

1. Postgres local (você já tem) — senha no `.env` (`POSTGRES_PASSWORD`).
2. Redis local na porta `6379`.
3. Ruby conforme `.ruby-version` + `bundle install`.
4. Node + `pnpm install`.
5. `.env` com:

```env
POSTGRES_HOST=localhost
POSTGRES_USERNAME=postgres
POSTGRES_PASSWORD=root
REDIS_URL=redis://localhost:6379
FRONTEND_URL=http://localhost:3000
RAILS_ENV=development
```

6. Prepare o banco:

```bash
bundle exec rails db:chatwoot_prepare
# ou, se o Chatwoot já estiver migrado:
bundle exec rails db:migrate
bundle exec rails db:seed
```

7. Suba a app:

```bash
pnpm dev
# ou
bundle exec rails s -p 3000
# + worker Sidekiq em outro terminal
# + vite (bin/vite dev)
```

8. Acesse `/app/accounts/1/internal-chat`.

---

## 10. Troubleshooting

| Sintoma | Verificação |
|---|---|
| Menu não aparece | Assets rebuildados? Rota `internal_chat_index` registrada? |
| 404 na API | `draw :internal_chat` no `routes.rb` + restart |
| Mensagens não chegam em tempo real | Redis up? `/cable` no proxy? Sidekiq rodando? |
| Erro de migration | Postgres acessível? Usuário com permissão de criar tabelas? |
| Anexo rejeitado | Tipo/tamanho permitidos? Active Storage configurado? |
| Usuário de outra empresa visível | Bug grave — abrir issue; consultas devem filtrar `account_id` |

---

## 11. Referência de produto

Especificação funcional: [`docs/Chatinterno.md`](./Chatinterno.md)
