# CLAUDE.md — contexto do projeto para o Claude Code

> Este arquivo é lido automaticamente pelo Claude Code ao abrir a pasta.
> Ele orienta o assistente. Quem opera esta máquina pode ser o **Yuri** ou o **Alf** —
> **os dois não são programadores**. Aja de acordo com as regras abaixo.

## Como falar com o operador

- Responda **sempre em português (BR)**, sem jargão técnico.
- Ao explicar o que você fez, descreva o **efeito prático** ("agora a foto sobe direto,
  sem precisar refazer o site"), não a implementação.
- Antes de mudar qualquer **regra de negócio**, **pergunte**. Regra de negócio é decisão do
  cliente (Alf). Detalhe técnico é a sua área — nesses, decida e siga.
- Antes de começar uma funcionalidade nova, faça um **brainstorm** curto para alinhar o
  fluxo antes de escrever código.

## O que é o projeto

**Camarim**, da LA Music (escola de música, Rio de Janeiro). É a plataforma que entrega e
vende o material audiovisual das **26 bandas** do Julina Rock Fest 2026. Cada banda tem uma
página num endereço secreto (`/b/<slug>-<token>/`); **o link é a credencial**, não há login
de cliente. Uma banda nunca pode alcançar o material de outra. Pagamento é **fora do site**,
por WhatsApp; o dono libera o download manualmente depois que a banda paga.

> 📖 **Leia o [`CAMARIM.md`](./CAMARIM.md) INTEIRO antes de escrever qualquer código.**
> Ele é a fonte da verdade: regras de negócio, esquema do banco, modelo de segurança,
> backlog (seção 12) e armadilhas conhecidas (seção 16). O [`README.md`](./README.md) tem o
> mapa das pastas e o estado atual.

## ⚠️ Regras de segurança — inegociáveis

- A **`service_role` key** e o **access token `sbp_…`** são chaves de administrador do banco
  inteiro. Elas vivem **apenas** no `.env.local` (ignorado pelo Git) e no painel do Supabase.
  **Nunca** podem ir para: o navegador, o `mesa-de-som.html`, a pasta `site/`, este repositório
  ou qualquer commit.
- No frontend, **só a anon key** (que é pública por design). Se precisar de privilégio de
  admin no cliente, a resposta é **Edge Function**, nunca chave no navegador.
- Antes de commitar, confira que nenhum valor secreto entrou em arquivo rastreado
  (`git grep --cached` pelos valores das chaves). O `.env.local` já está no `.gitignore`.
- **Não "conserte"** os avisos `security_definer_executable` de `abrir_camarim` e
  `registra_acesso` — são propositais (seção 7 do CAMARIM.md).

## Estado atual

- ✅ Backend no ar no Supabase (projeto `hpeyyamwoisehqylrdtx`): tabelas, RLS, buckets de
  Storage, Edge Function `camarim`, admins, 33 testes de segurança passando.
- ✅ Página da banda (`site/b/.../index.html`) pronta e revisada.
- 🔴 **Próxima tarefa (backlog #1):** migrar o `mesa-de-som.html` de IndexedDB para o
  Supabase (login de admin, upload de fotos/vídeos para o Storage, botão "Liberar banda").
  **Preservar** o motor atual que já funciona (arrastar fotos, marca d'água em Canvas,
  redimensionar, gerar zip como plano B).

## Estrutura

```
mesa-de-som.html    painel do admin (roda no navegador; NÃO sobe no Netlify)
site/               frontend estático (o que vai para o Netlify) + exemplo da banda Crowns
supabase/           migrations + Edge Function camarim (já aplicadas em produção)
CAMARIM.md          documento-mestre (fonte da verdade)
README.md           mapa e estado do projeto
.env.local          credenciais locais (NÃO versionado)
.env.example        template das credenciais
```

## Observação sobre dependências

Hoje o projeto é **HTML estático** — não há `package.json` nem `npm install` a rodar. As
"dependências" são só as ferramentas (Node, Git, Supabase CLI). Quando a migração começar e
for preciso o cliente JS do Supabase (`@supabase/supabase-js`), adicione conforme a
necessidade — e explique ao operador, em português, o porquê.
