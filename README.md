# Camarim — LA Music

> Plataforma de entrega e venda de material audiovisual da LA Music.
> Repositório **privado**. Backend no ar, frontend em migração para o Supabase.

O projeto agora tem dois fluxos independentes no mesmo código:

- **Julina Rock Fest:** o Camarim original por banda, preservado sem mudanças nas regras.
- **Entregas por aluno/família:** plataforma reutilizável para o Vocal Kids e eventos futuros,
  com uma página privada por link e sincronização somente de leitura com o CRM.

> 📦 A documentação da plataforma reutilizável está em [`ENTREGAS.md`](./ENTREGAS.md).

A LA Music (escola de música, Rio de Janeiro) filmou e fotografou **26 bandas de alunos**
no Julina Rock Fest 2026. O Camarim é onde esse material é **mostrado** e **vendido**: cada
banda tem uma página própria num endereço secreto e **nunca** enxerga o material de outra.
Não há login para o cliente — **o link é a credencial**.

```
https://camarim.lamusicschool.com.br/b/crowns-x7k92m/
                                        └──┬──┘ └──┬──┘
                                         slug    token secreto
```

O pagamento acontece **fora do site**, por WhatsApp. O dono (Alf) libera o download
manualmente depois que a banda paga.

> 📖 **A fonte da verdade é o [`CAMARIM.md`](./CAMARIM.md)** — regras de negócio, esquema
> do banco, modelo de segurança, backlog e armadilhas conhecidas. Leia-o inteiro antes de
> escrever qualquer código.

---

## Estrutura

```
bora-gravar/
├── CAMARIM.md                    documento-mestre (regras, schema, segurança, backlog)
├── LEIA-ME.txt                   manual do Alf para o fluxo estático (Netlify manual)
├── README.md                     este arquivo
├── vercel.json                   publica só site/, mantém /b/<chave>/ e aplica noindex
├── .env.example                  template das variáveis de ambiente
├── .env.local                    credenciais reais — NÃO versionado (.gitignore)
│
├── mesa-de-som.html              painel do admin (roda no navegador, NÃO sobe na Vercel)
├── mesa-de-entregas.html         painel de entregas por aluno/família (NÃO sobe na Vercel)
│
├── site/                         frontend estático (o que vai para a Vercel)
│   ├── index.html                página inicial (quem chega sem link)
│   ├── pagina.html               página real da banda — busca os dados no Supabase pela chave da URL
│   ├── entrega.html              página privada de entrega por aluno/família (`/e/<chave>/`)
│   ├── _redirects                Netlify: manda /b/* pra pagina.html (URL limpa)
│   ├── robots.txt                Disallow: / — mantém fora do Google
│   ├── _headers                  X-Robots-Tag: noindex
│   └── b/crowns-x7k92m/          protótipo antigo (dados.js estático) — mantido só de referência
│
└── supabase/                     backend (já aplicado no projeto hpeyyamwoisehqylrdtx)
    ├── functions/camarim/index.ts        Edge Function do Julina (links assinados 1h)
    ├── functions/entrega/index.ts        portal privado por aluno/família
    ├── functions/entregas-admin/index.ts sincronização segura com o CRM
    └── migrations/
        ├── 20260825_0001_schema.sql      tabelas, tipos, triggers, índices
        ├── 20260825_0002_buckets.sql     previas (público) / originais (privado)
        ├── 20260825_0003_rls.sql         RLS, abrir_camarim, policies de storage
        ├── 20260825_0004_ajustes.sql     search_path, freio de log, limpeza
        └── 20260825_0005_admin.sql       allowlist de admin + grant do gera_token
```

---

## Estado atual

| Parte | Status |
|---|---|
| Banco de dados (Supabase) | ✅ **no ar** — tabelas, triggers, RLS, 33 testes de segurança passando |
| Buckets de Storage (`previas` público, `originais` privado) | ✅ no ar |
| Edge Function `camarim` (links assinados) | ✅ no ar |
| Admins (`lucianoalf.la@gmail.com`, `yuristanzi@gmail.com`, `eujohnatansilva@gmail.com`) | ✅ criados |
| Página da banda (`site/pagina.html`, conectada ao Supabase) | 🟡 **código pronto e testado ponta a ponta com dados de teste** — falta um teste com uma banda de verdade, publicada pela Mesa de Som |
| **Mesa de Som → Supabase** | ✅ **sincronizada** — login, upload, liberação e leitura das bandas publicadas funcionam em qualquer navegador; verificada com 28 bandas, 395 fotos e 48 vídeos reais |
| **Entregas multi-eventos** | ✅ **no ar** — banco, painel, portal privado e sincronização do CRM prontos; Vocal Kids iniciado com os contratantes do CRM em rascunho |
| Deploy Vercel + domínio | 🟡 configuração pronta; falta importar o GitHub e apontar o CNAME no Registro.br |
| Cadastro em lote das 26 bandas | 🟡 pendente |

O backlog completo e priorizado está na **seção 12 do [`CAMARIM.md`](./CAMARIM.md)**.

---

## ⚠️ Segurança — regra inegociável

A **`service_role` key** e o **access token `sbp_…`** são chaves de administrador do banco
inteiro. Elas vivem **apenas** no `.env.local` (ignorado pelo Git) e no painel do Supabase.

**Nunca** podem aparecer em:
- qualquer arquivo dentro de `site/` (vai para a Vercel)
- qualquer JavaScript que rode no navegador, incluindo `mesa-de-som.html`
- este README, o `CAMARIM.md` ou qualquer commit

No frontend, **só a anon key**. Se precisar de privilégio de admin no cliente, a resposta é
**Edge Function**, não chave no navegador.

---

## Configuração local

```bash
# 1. Copie o template e preencha com as credenciais reais
cp .env.example .env.local
# (pegue os valores em Supabase → Settings → API Keys)

# 2. (Opcional) Vincule o Supabase CLI ao projeto
supabase link --project-ref hpeyyamwoisehqylrdtx
```

### Rodar cada parte

| O quê | Como |
|---|---|
| **Mesa de Som** (painel do admin) | Abrir `mesa-de-som.html` no navegador (duplo clique) |
| **Mesa de Entregas** (eventos novos) | Abrir `mesa-de-entregas.html`, entrar e escolher o evento |
| **Site** (frontend) | Servir a pasta `site/` estático — ex.: `npx serve site` |
| **Migrations** (ambiente novo) | `supabase db push` — reconstrói o banco do zero |
| **Edge Function** | `supabase functions deploy camarim` |
| **Edge Functions de entrega** | `supabase functions deploy entrega` e `supabase functions deploy entregas-admin` |

> As migrations **já estão aplicadas** no projeto de produção `hpeyyamwoisehqylrdtx`.
> Só rode `supabase db push` se estiver montando um ambiente limpo.

---

## Regras de negócio fechadas (não reabrir)

- **Pagamento 100% fora do site**, por WhatsApp `+55 21 98258-3946`. Sem PIX/gateway na página.
- **Pacotes:** 01 Melhores Momentos R$ 300 · 02 Duas Músicas R$ 500 · 03 Completo R$ 700.
- **Fotos só no Pacote Completo (R$ 700).** Sem pacote de fotos avulso, sem upsell pós-compra.
- **Capa = sempre a foto da banda inteira, e sempre cortesia** (trava por trigger no banco).
- **Link do Google Drive não toca no `<video>`** — Drive serve só para o botão de baixar.
- **Não diminuir a marca d'água** (já foi aumentada a pedido do cliente).

Detalhes e o "porquê" de cada uma na seção 3 do [`CAMARIM.md`](./CAMARIM.md).

---

## Créditos

Audiovisual — **John Silva** e **Yuri Stanzi** · Áudio — **Vanderson Tomaz** ·
Produção — **LA Music**.

*Camarim — LA Music · Julina Rock Fest 2026*
