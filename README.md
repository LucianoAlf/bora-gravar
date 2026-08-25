# Camarim — LA Music

> Plataforma de entrega e venda do material audiovisual do **Julina Rock Fest 2026**.
> Repositório **privado**. Backend no ar, frontend em migração para o Supabase.

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
├── .env.example                  template das variáveis de ambiente
├── .env.local                    credenciais reais — NÃO versionado (.gitignore)
│
├── mesa-de-som.html              painel do admin (roda no navegador, NÃO sobe no Netlify)
│
├── site/                         frontend estático (o que vai para o Netlify)
│   ├── index.html                página inicial (quem chega sem link)
│   ├── robots.txt                Disallow: / — mantém fora do Google
│   ├── _headers                  X-Robots-Tag: noindex
│   └── b/crowns-x7k92m/          página de exemplo da banda Crowns (protótipo)
│       ├── index.html            o template renderizado
│       ├── dados.js              window.DADOS — o único arquivo que se edita no fluxo antigo
│       └── img/                  fotos da banda (capa, alta f01–f08, marca d'água w*, poster)
│
└── supabase/                     backend (já aplicado no projeto hpeyyamwoisehqylrdtx)
    ├── functions/camarim/index.ts        Edge Function de download (links assinados 1h)
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
| Admins (`lucianoalf.la@gmail.com`, `yuristanzi@gmail.com`) | ✅ criados |
| Página da banda (`pagina.html`) | ✅ pronta e revisada |
| **Mesa de Som → Supabase** | 🔴 **próxima tarefa** — hoje usa IndexedDB + zip manual |
| Página da banda → Edge Function | 🔴 pendente |
| Deploy Netlify + domínio | 🟡 pendente (CNAME no Registro.br) |
| Cadastro em lote das 26 bandas | 🟡 pendente |

O backlog completo e priorizado está na **seção 12 do [`CAMARIM.md`](./CAMARIM.md)**.

---

## ⚠️ Segurança — regra inegociável

A **`service_role` key** e o **access token `sbp_…`** são chaves de administrador do banco
inteiro. Elas vivem **apenas** no `.env.local` (ignorado pelo Git) e no painel do Supabase.

**Nunca** podem aparecer em:
- qualquer arquivo dentro de `site/` (vai para o Netlify)
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
| **Site** (frontend) | Servir a pasta `site/` estático — ex.: `npx serve site` |
| **Migrations** (ambiente novo) | `supabase db push` — reconstrói o banco do zero |
| **Edge Function** | `supabase functions deploy camarim` |

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
