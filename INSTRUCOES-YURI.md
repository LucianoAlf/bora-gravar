# 🎸 Guia do Yuri — Camarim / LA Music

Bem-vindo, Yuri! Este guia te leva do zero até o projeto rodando na sua máquina, com o
Claude Code fazendo o trabalho pesado. **Você não precisa saber programar** — é só seguir os
passos e colar os prompts na ordem.

Leva uns 15 minutos. Qualquer travada, manda pro Alf.

---

## ✅ Antes de começar (o Alf faz junto com você)

Você vai precisar de 4 coisas instaladas no computador:

| Ferramenta | Para quê | Onde pegar |
|---|---|---|
| **Claude Code** | é onde você vai trabalhar | https://claude.com/claude-code |
| **Git** | baixar o projeto | https://git-scm.com/downloads |
| **Node.js** (versão LTS) | roda as ferramentas | https://nodejs.org |
| **GitHub CLI** (`gh`) | login no GitHub | https://cli.github.com |

E mais duas coisas que **o Alf libera pra você**:

1. **Acesso ao repositório privado** — o Alf te adiciona como colaborador no GitHub
   (o projeto é privado, então sem isso você não consegue baixar).
2. **Login do Supabase** — você já é admin com o e-mail `yuristanzi@gmail.com`. Guarde a
   senha; você vai usar pra pegar duas chaves secretas mais pra frente.

---

## 📥 Passo 1 — Baixar o projeto e abrir o Claude Code

Abra o **Terminal** (no Windows: "Prompt de Comando" ou "PowerShell"; no Mac: "Terminal") e
cole estes comandos, **um de cada vez**, apertando Enter:

```bash
gh auth login
```
> Isso faz seu login no GitHub. Escolha **GitHub.com** → **HTTPS** → **Login with a web
> browser**, e siga na tela. Faça uma vez só.

```bash
gh repo clone LucianoAlf/bora-gravar
```
> Baixa o projeto para uma pasta chamada `bora-gravar`.

```bash
cd bora-gravar
```
> Entra na pasta do projeto.

```bash
claude
```
> Abre o Claude Code **dentro da pasta do projeto**. É aqui que a mágica acontece.

Pronto — agora é só conversar com o Claude Code colando os prompts abaixo.

---

## 💬 Passo 2 — Os 4 prompts (cole um de cada vez)

Cole o **Prompt 1**, espere o Claude Code responder, leia, e só então cole o **Prompt 2**, e
assim por diante. Sem pressa.

### ▶️ Prompt 1 — Conhecer o projeto

```
Você está assumindo o projeto Camarim, da LA Music. Antes de qualquer coisa, leia os
arquivos CLAUDE.md, README.md e CAMARIM.md inteiros — são a fonte da verdade do projeto.
Depois me explique, em português e sem termos técnicos: o que é o projeto, o que já está
pronto e o que falta fazer. Ainda não escreva nenhum código.
```

### ▶️ Prompt 2 — Montar o ambiente e as credenciais

Antes de colar, tenha em mãos as **duas chaves secretas** (veja a seção "🔑 Credenciais" mais
abaixo). Cole tudo junto:

```
Agora prepare esta máquina para o projeto. Verifique se eu tenho Node.js, Git e o Supabase
CLI instalados e me diga, em português, o que falta e como instalar. Em seguida crie o
arquivo .env.local a partir do .env.example, preenchendo as chaves públicas (URL e anon key
estão no README/CAMARIM.md). As duas chaves secretas seguem abaixo. Confirme que o
.env.local está no .gitignore e que nenhum segredo vai para o Git.

SUPABASE_SERVICE_ROLE_KEY = (cole aqui — pegue no painel do Supabase)
SUPABASE_ACCESS_TOKEN = (cole aqui — gere no painel do Supabase)
```

### ▶️ Prompt 3 — Testar se conectou

```
Teste a conexão com o Supabase e me confirme, em português, que está tudo certo:
1) que pedir a lista de bandas com a chave pública dá "permission denied" (isso é o esperado
   e prova que a segurança está de pé);
2) que a Edge Function do Camarim responde.
Me mostre o resultado.
```

### ▶️ Prompt 4 — Começar a trabalhar

```
Vamos começar a primeira tarefa do backlog (seção 12 do CAMARIM.md): migrar a Mesa de Som
(mesa-de-som.html) de IndexedDB para o Supabase — login de admin, upload das fotos e vídeos
para o Storage e o botão "Liberar banda". Preserve o motor que já funciona (arrastar fotos,
marca d'água, redimensionar, gerar zip). Antes de escrever código, faça um brainstorm comigo
para alinharmos o fluxo. Escreva tudo em português.
```

A partir daqui é conversa normal: você pede, o Claude Code faz, e vai explicando em
português. Toque o barco. 🚣

---

## 🔑 Credenciais (as duas chaves secretas do Prompt 2)

O projeto precisa de duas chaves de administrador. **Elas nunca podem ser coladas em nenhum
arquivo que vá pro GitHub** — por isso não estão neste guia. Você pega você mesmo, no painel
do Supabase, logado como `yuristanzi@gmail.com`:

**1. `SUPABASE_SERVICE_ROLE_KEY`**
- Entre em https://supabase.com/dashboard → projeto **Bora Gravar**.
- Menu **Settings → API Keys**.
- Copie a chave marcada como **`service_role`** (a longa, `secret`).

**2. `SUPABASE_ACCESS_TOKEN`** *(só se for usar o Supabase CLI para publicar mudanças — pode
deixar pra depois)*
- Entre em https://supabase.com/dashboard/account/tokens.
- Clique em **Generate new token**, dê um nome (ex.: "Yuri notebook") e copie o valor
  (começa com `sbp_`). **Ele só aparece uma vez** — copie na hora.

> As chaves **públicas** (URL, anon key) já estão no repositório e o Claude Code preenche
> sozinho. Só essas duas secretas é que você cola.

---

## 🚦 Regras de ouro (importante)

- **Nunca** cole a `service_role` ou o token `sbp_` em nada que não seja o `.env.local`. Se o
  Claude Code sugerir colocar chave secreta no site ou no código do navegador, **recuse** —
  ele sabe a regra, mas confira.
- **Não mude preço, pacote ou regra de venda** por conta própria. Isso é decisão do Alf —
  pergunte antes.
- Se algo parecer errado ou você ficar em dúvida, **peça pro Claude Code explicar em
  português** antes de confirmar. E na dúvida, chama o Alf.

---

## 🆘 Se travar

| Problema | O que fazer |
|---|---|
| `gh repo clone` diz que não achou / sem permissão | O Alf ainda não te adicionou como colaborador. Peça pra ele. |
| Não sei se instalei tudo | Cole o **Prompt 2** — o Claude Code verifica e te diz o que falta. |
| Perdi qual prompt colar | Volte aqui e siga a ordem: 1 → 2 → 3 → 4. |
| Deu um erro vermelho que não entendi | Copie o erro, cole no Claude Code e peça: "explica isso em português e resolve". |

---

*Camarim — LA Music · Julina Rock Fest 2026 · guia feito para o Yuri*
