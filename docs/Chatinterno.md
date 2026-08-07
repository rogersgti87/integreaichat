# Implementação do Módulo "Internal Chat" para Chatwoot

## Objetivo

Desenvolver um módulo de **Chat Interno** dentro do Chatwoot Open Source que permita a comunicação entre agentes/usuários da plataforma **sem utilizar qualquer canal externo** (WhatsApp, Meta, Evolution API, Twilio, etc.).

O módulo deverá utilizar exclusivamente a infraestrutura do próprio Chatwoot (autenticação, ActionCable/WebSockets, Redis e usuários existentes).

---

# Objetivos Principais

- Comunicação entre agentes em tempo real.
- Não consumir créditos da Meta.
- Não criar conversas do Chatwoot.
- Não utilizar Inboxes.
- Não utilizar Contacts.
- Não utilizar Conversations.
- Não utilizar Messages do Chatwoot.
- Utilizar apenas usuários internos (Agents/Administradores).
- Ser completamente independente do módulo de atendimento.

---

# Requisito mais importante

## A implementação deve ser totalmente desacoplada do núcleo do Chatwoot.

Evitar modificar:

- app/models/conversation*
- app/models/message*
- app/models/contact*
- app/models/inbox*
- app/services relacionados ao atendimento
- APIs existentes
- Fluxo de atendimento

O objetivo é permitir futuras atualizações do Chatwoot com o menor número possível de conflitos.

Toda a implementação deverá ficar em um módulo separado.

---

# Arquitetura

Criar um novo módulo chamado:

```
Internal Chat
```

Novo item na Sidebar:

```
Inbox

Contacts

Automation

Reports

Settings

-----------------------

💬 Internal Chat
```

Este módulo será totalmente independente do Inbox.

---

# Banco de Dados

Criar novas tabelas.

## internal_conversations

Campos:

- id
- account_id
- created_by_id
- conversation_type (private/group)
- created_at
- updated_at

---

## internal_conversation_participants

Campos:

- id
- conversation_id
- user_id
- last_read_message_id
- joined_at

---

## internal_messages

Campos:

- id
- conversation_id
- sender_id
- message
- message_type
- reply_to
- edited_at
- deleted_at
- created_at
- updated_at

---

## internal_message_attachments

Campos:

- id
- message_id
- file
- created_at

---

# Backend

Criar namespace próprio.

Exemplo:

```
app/controllers/internal_chat/
```

Controllers:

```
InternalConversationsController

InternalMessagesController

InternalParticipantsController
```

Criar Services próprios.

Exemplo:

```
InternalChat::CreateConversation

InternalChat::SendMessage

InternalChat::MarkAsRead

InternalChat::SearchConversation

InternalChat::SearchUsers
```

---

# Websocket

Utilizar ActionCable existente do Chatwoot.

Criar canal próprio.

Exemplo:

```
InternalChatChannel
```

Nunca reutilizar canais do Inbox.

---

# Front-end

Criar páginas próprias.

Exemplo:

```
app/javascript/dashboard/routes/internalChat
```

Componentes próprios.

Nunca alterar componentes do Inbox.

---

# Layout

Interface semelhante ao WhatsApp Desktop.

Lado esquerdo:

- Pesquisa
- Conversas

Lado direito:

- Cabeçalho
- Mensagens
- Campo de digitação

Rodapé:

- Emoji
- Upload
- Caixa de texto
- Botão enviar

---

# Funcionalidades da primeira versão

## Conversas privadas

Permitir criar conversa entre dois agentes.

---

## Lista de usuários

Mostrar todos os usuários ativos da conta.

Exibir:

- Avatar
- Nome
- Cargo
- Online
- Offline

---

## Mensagens

Permitir:

- texto
- emoji

---

## Upload

Permitir:

- imagem
- pdf
- word
- excel
- zip

---

## Indicador digitando

Mostrar:

```
João está digitando...
```

---

## Lido

Mostrar:

✓ enviado

✓✓ entregue

✓✓ lido

---

## Pesquisa

Pesquisar:

- usuário
- conversa
- conteúdo das mensagens

---

## Notificações

Notificação em tempo real.

Badge na sidebar.

Som.

Toast.

---

## Status

Mostrar:

- online
- offline

---

## Ordenação

Última conversa sempre no topo.

---

# Segurança

Cada usuário só poderá visualizar conversas das quais participa.

Nunca permitir acesso por URL alterando IDs.

Todas as consultas devem validar permissões.

---

# Performance

Utilizar:

- Paginação
- Lazy Loading
- Infinite Scroll
- Broadcast apenas para participantes
- Consultas otimizadas

---

# Integração

Reutilizar somente:

- Usuários
- Permissões
- Login
- Avatar
- Redis
- ActionCable
- Layout Dashboard

Não reutilizar:

- Conversation
- Inbox
- Message
- Contact
- Channel
- APIs de atendimento

---

# Organização

Toda implementação deve ficar em namespace próprio.

Exemplo:

```
app/controllers/internal_chat/

app/models/internal_chat/

app/services/internal_chat/

app/javascript/dashboard/internalChat/

config/routes/internal_chat.rb
```

Evitar espalhar arquivos pelo projeto.

---

# Atualizações futuras

A arquitetura deverá permitir adicionar posteriormente:

- Conversas em grupo
- Canais
- Chamadas de voz
- Chamadas de vídeo
- Compartilhamento de tela
- Mensagens fixadas
- Reações
- Respostas
- Menções
- Threads

Sem necessidade de alterar a arquitetura criada agora.

---

# Qualidade do Código

- Seguir padrões utilizados pelo Chatwoot.
- Código limpo.
- Componentização.
- SOLID.
- Baixo acoplamento.
- Alta coesão.
- Documentação inline.
- Testes unitários quando aplicável.

---

# Objetivo Final

Ao término da implementação deverá existir um novo módulo chamado **Internal Chat**, totalmente integrado visualmente ao Chatwoot, porém arquiteturalmente independente do módulo de atendimento.

O usuário deverá perceber que é uma funcionalidade nativa da plataforma, enquanto o código permanecerá desacoplado do núcleo do Chatwoot, minimizando conflitos em futuras atualizações do projeto.


# Multiempresa (Obrigatório)

O módulo deve seguir exatamente a arquitetura multiempresa (multi-tenant) do Chatwoot.

## Regras

- Toda conversa pertence a uma única Account.
- Todo usuário pertence a uma ou mais Accounts.
- Apenas usuários pertencentes à mesma Account podem iniciar ou participar de conversas.
- Nunca permitir comunicação entre usuários de Accounts diferentes.
- Todas as consultas devem ser filtradas por account_id.
- Todas as permissões devem validar o account_id antes de retornar qualquer informação.

## Exemplos

Empresa A

- João
- Maria
- Pedro

Podem conversar entre si.

---

Empresa B

- Carlos
- Fernanda

Podem conversar entre si.

---

João (Empresa A)

❌ Não pode visualizar Carlos.

❌ Não pode iniciar conversa com Carlos.

❌ Não pode localizar Carlos na pesquisa.

❌ Não pode acessar conversas da Empresa B alterando URLs.

---

# Isolamento

Todo registro criado deverá possuir o campo:

account_id

Esse campo será obrigatório nas tabelas:

- internal_conversations
- internal_conversation_participants
- internal_messages
- internal_message_attachments

Todas as consultas SQL e ActiveRecord deverão obrigatoriamente filtrar por:

account_id = Current.account.id

Nunca confiar apenas no ID da conversa.

Sempre validar também:

- account_id
- participante da conversa

antes de retornar qualquer dado.

# Autorização

Utilizar o sistema de permissões já existente do Chatwoot.

O usuário deverá visualizar apenas:

- usuários da mesma Account;
- conversas da mesma Account;
- arquivos da mesma Account;
- notificações da mesma Account.

Nunca criar um sistema de autenticação paralelo.

Deverá reutilizar integralmente o modelo Account + User do Chatwoot.

---

# Documentação de produção

Guia para implantar em ambientes novos ou Chatwoot já em produção:

→ [`docs/internal-chat-producao.md`](./internal-chat-producao.md)
