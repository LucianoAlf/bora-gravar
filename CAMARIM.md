# CAMARIM — LA Music
### Plataforma de entrega e venda do material audiovisual do Julina Rock Fest 2026

> **Documento de passagem.** Escrito para ser lido por outro agente (Claude Code) que vai
> continuar o desenvolvimento, e pelo Alf, que opera a plataforma no dia a dia.
> Tudo que está descrito aqui como "pronto" já está aplicado e testado no Supabase.
>
> Última atualização: 25/08/2026

---

## 1. O que é

A LA Music (escola de música, Rio de Janeiro) filmou e fotografou **26 bandas de alunos** no
**Julina Rock Fest 2026** — 22 de agosto de 2026, Shopping Time Center, Recreio/RJ.

O Camarim é o lugar onde esse material é **mostrado** e **vendido**. Não é uma galeria de
fotos genérica: é uma vitrine premium, na estética da marca, feita para dar orgulho ao aluno
e vontade de comprar ao pai que abre o link.

**A regra que organiza tudo:** cada banda tem uma página própria, num endereço secreto, e
**nunca** consegue ver o material de outra banda. Não existe login para o cliente — o link
*é* a credencial.

```
https://camarim.lamusicschool.com.br/b/crowns-x7k92mqa4d/
                                        └──┬──┘ └────┬────┘
                                         slug     token secreto
```

---

## 2. Como funciona na prática

### Jornada do cliente (pai / aluno)

1. Recebe o link da banda no WhatsApp. Só o link, sem senha.
2. Abre e vê: foto de capa da banda em tela cheia, o nome grandão, um clipe curto tocando,
   as fotos com marca d'água, 3 ou 4 fotos de cortesia limpas, os três pacotes e os créditos
   da produção.
3. Escolhe um pacote e clica em **"Quero esse"** → abre o WhatsApp da escola com uma
   mensagem já escrita, identificando a banda e o pacote.
4. Paga por lá (PIX, direto com o Alf). **Não existe pagamento dentro do site.**
5. O Alf libera a banda. A mesma página muda sozinha: some a parte de venda, as fotos ficam
   sem marca e aparecem os botões de download.
6. **Um integrante paga pela banda toda.** Depois de liberado, todo mundo baixa por esse
   mesmo link, quantas vezes quiser.

### Jornada do Alf (quem sobe o conteúdo)

1. Edita o material.
2. Abre a **Mesa de Som** (painel administrativo), cria a banda, arrasta as fotos, marca
   qual é a **capa** e quais são **cortesia**, sobe o clipe curto e cola os links dos vídeos
   completos.
3. Publica. A página da banda entra no ar naquele endereço secreto.
4. Manda o link pra banda no WhatsApp.
5. Quando alguém paga, ele marca a banda como **liberada** e o download abre na hora.

---

## 3. Regras de negócio — fechadas, não reabrir

| Regra | Detalhe |
|---|---|
| **Pagamento** | 100% fora do site, por WhatsApp: **+55 21 98258-3946** (`5521982583946`). Nunca voltar a colocar PIX/gateway na página. |
| **Pacotes** | 01 — Melhores Momentos · **R$ 300**<br>02 — 2 Músicas Completas · **R$ 500**<br>03 — Pacote Completo · **R$ 700** |
| **Fotos** | Só entram no **Pacote Completo (R$ 700)**. Não existe pacote de fotos avulso — canibalizaria o tier de cima. |
| **Upsell** | **Não fazer.** Quem comprou o de R$ 300 ou R$ 500 não recebe oferta de foto depois. Decisão do Alf. |
| **Quem paga** | Um integrante paga pela banda inteira. Todos baixam pelo mesmo link. |
| **Capa** | **Sempre** a foto geral da banda (todo mundo junto). Regra travada no banco por trigger. |
| **Cortesia** | 3 ou 4 fotos limpas de graça, para criar desejo. A capa é sempre cortesia. |
| **Prazo de escolha** | 10 de setembro de 2026 |
| **Validade do link** | 30 de setembro de 2026 |
| **Créditos** | Audiovisual — **John Silva** e **Yuri Stanzi** · Áudio — **Vanderson Tomaz** · Produção — **LA Music**.<br>Sem metadados de câmera. O bloco de créditos é um convite a postar e marcar a escola. |
| **Tom dos botões** | "Quero esse". Nada agressivo tipo "Liberar tudo com PIX" — foi vetado explicitamente. |
| **Bandas** | 26 no total. Prever uma banda extra "Julina Geral" (página aberta, tudo cortesia, para equipe/divulgação). |

### Frase que não pode ser reescrita
> "Um integrante resolve pela banda toda. Depois de liberado, todo mundo baixa por esse
> mesmo link, quantas vezes quiser."

Já foi reescrita uma vez e o Alf pediu a original de volta. Ela fica em destaque na página.

---

## 4. Arquitetura

```
┌──────────────────────────────┐        ┌───────────────────────────────────┐
│  VERCEL  (frontend estático) │        │  SUPABASE  "Bora Gravar"          │
│                              │        │  sa-east-1 · Postgres 17          │
│  /                index.html │        │                                   │
│  /b/<slug>-<token>/          │◄──────►│  Postgres  (bandas/fotos/videos)  │
│         index.html           │  anon  │  Storage   previas   (público)    │
│         (lê window.DADOS ou  │  key   │            originais (privado)    │
│          chama o Supabase)   │        │  Edge Fn   /functions/v1/camarim  │
│  robots.txt  noindex         │        │  Auth      só admin (Alf, Yuri)   │
│  vercel.json: rota + noindex │        │                                   │
└──────────────────────────────┘        └───────────────────────────────────┘
         ▲
         │  mesa-de-som.html  (painel do Alf — roda no navegador dele,
         │                     NÃO sobe na Vercel)
```

**Por que Supabase e não só arquivo estático:** com arquivo estático, liberar uma banda exigia
editar `dados.js` na mão e refazer o deploy. Com o Supabase é um clique na Mesa de Som, e o
material em alta fica atrás de link assinado em vez de ficar público numa pasta.

**Custo de storage:** ~80 GB para as 26 bandas. Se o Storage do Supabase ficar caro, o plano B
é Cloudflare R2 (US$ 0,015/GB/mês, **egress zero**, 10 GB grátis) — nesse caso o `path_alta`
vira uma URL do R2 e a Edge Function assina lá em vez de assinar no Supabase.

---

## 5. Conexão com o Supabase

| | |
|---|---|
| **Projeto** | Bora Gravar |
| **Project ref** | `hpeyyamwoisehqylrdtx` |
| **URL** | `https://hpeyyamwoisehqylrdtx.supabase.co` |
| **Região** | `sa-east-1` (São Paulo) |
| **Postgres** | 17.6 |
| **Organização** | `bwykmmgfkuyfplgbiflh` |

**Chave pública (pode ir no frontend, é feita pra isso):**

```
anon key       eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhwZXl5YW13b2lzZWhxeWxyZHR4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc2ODEyOTUsImV4cCI6MjEwMzI1NzI5NX0.PuameozNXedB46WdZjBcGwCWzTb3YGdROA3NRMjNHh8
publishable    sb_publishable__QJzWmwB7k2eVXkt1LOyag_26J72Q3h
```

### ⚠️ Regra de segurança inegociável

> A **service_role key** e o **access token `sbp_…`** são chaves de administrador do banco
> inteiro. Elas **nunca** podem aparecer em:
> - qualquer arquivo que suba na Vercel
> - qualquer JavaScript que rode no navegador
> - o `mesa-de-som.html`
> - este documento, um README, ou um repositório
>
> Elas vivem só em dois lugares: no painel do Supabase e nas variáveis de ambiente da Edge
> Function (onde `SUPABASE_SERVICE_ROLE_KEY` já é injetada automaticamente).
> Pegue-as em **Settings → API Keys** no painel quando precisar.

### Logins de administrador (já criados)

| E-mail | Papel |
|---|---|
| `lucianoalf.la@gmail.com` | Alf — dono |
| `yuristanzi@gmail.com` | Yuri Stanzi — audiovisual |

Ambos entram por e-mail + senha e já estão em `public.admins`.
**Trocar a senha depois do primeiro login** (as duas foram criadas com a mesma).

Para autorizar mais gente: basta inserir o e-mail em `public.admins_permitidos` **antes** de
criar o usuário no painel. O trigger `trg_promove_admin` promove sozinho, sem SQL manual.

---

## 6. Esquema do banco

Migrations completas em `supabase/migrations/`. Resumo do que existe:

### `public.bandas`
O registro central. Uma linha por banda.

| Coluna | Tipo | Observação |
|---|---|---|
| `id` | uuid PK | |
| `nome` | text | "Crowns" |
| `slug` | text UNIQUE | "crowns" |
| `token` | text | 12 chars aleatórios, default `gera_token(12)` |
| `chave` | text UNIQUE **generated** | `slug \|\| '-' \|\| token` — **é o endereço da página** |
| `evento` | text | default 'Julina Rock Fest 2026' |
| `data_evento` `local` `prazo` `validade` | date/text | |
| `whatsapp` | text | default '5521982583946' |
| `total_fotos` `total_musicas` `resolucao` `sobre_video` | | textos da página |
| `pacotes` `creditos` `equipe` | jsonb | conteúdo editorial, default `[]` |
| `estado` | enum | `rascunho` \| `publicada` \| `liberada` |
| `aberta` | bool | página aberta: tudo cortesia, sem venda (banda "Julina Geral") |
| `liberado` | bool | **pagou** → libera alta resolução |
| `pacote_comprado` `valor` `liberada_em` | | preenchidos na liberação |
| `criado_em` `atualizado_em` | timestamptz | |

Alfabeto do token: `abcdefghijkmnpqrstuvwxyz23456789` (32 chars, sem `l`/`o`/`0`/`1` pra não
confundir na hora de ditar). 12 posições ≈ **10¹⁸ combinações** — não se adivinha por força bruta.

### `public.fotos`

| Coluna | Observação |
|---|---|
| `banda_id` → `bandas` ON DELETE CASCADE | |
| `ordem` `nome_original` | |
| **`path_previa`** | o que **aparece** na página → bucket **público** `previas`.<br>Foto normal = versão com marca d'água. Cortesia = versão limpa em resolução de tela. |
| **`path_alta`** | o arquivo em alta, sem marca → bucket **privado** `originais` |
| `cortesia` `capa` | bool |
| `largura` `altura` `bytes` | |

- Índice único parcial: **uma capa por banda**.
- Trigger `trg_capa_cortesia`: **a capa vira cortesia automaticamente**, sempre.

### `public.videos`

| Coluna | Observação |
|---|---|
| `banda_id` `ordem` `titulo` `duracao` | |
| `previa` bool | o **único** vídeo que toca antes de pagar (índice único parcial) |
| `path_previa` | clipe curto com marca → bucket **público** |
| `path_alta` | vídeo completo → bucket **privado** |
| `url_externa` | ou link de fora (Google Drive), revelado **só depois de liberar** |
| `poster_path` `bytes` | |

### `public.downloads`
Links avulsos de fora (Drive, WeTransfer). `titulo`, `descricao`, `tamanho`, `url`, `ordem`.
**Só aparecem depois que a banda é liberada.**

### `public.acessos`
Log: `banda_id`, `chave`, `tipo` (`abriu` \| `baixou` \| `chave_invalida`), `detalhe`, `criado_em`.
Serve para o Alf ver quem abriu e quem baixou, e para detectar alguém martelando chaves.
`limpa_acessos()` apaga o que passar de 90 dias.

### `public.admins` / `public.admins_permitidos`
Quem pode operar a Mesa de Som. Explicado na seção 5.

### Triggers
| Trigger | O que faz |
|---|---|
| `trg_capa_cortesia` | capa ⇒ cortesia |
| `trg_bandas_atualizado` | mantém `atualizado_em` |
| `trg_liberacao` | ao virar `liberado=true`: carimba `liberada_em` e muda `estado` para `liberada` |
| `trg_promove_admin` | novo usuário no allowlist vira admin sozinho |

---

## 7. Segurança — o modelo, e por quê

Esse foi o ponto que o Alf mais cobrou: *"não pode baixar foto de outros alunos ou de outras
bandas"*. O desenho tem **quatro camadas**.

### Camada 1 — o visitante não enxerga tabela nenhuma

RLS ligado (e `FORCE`) em todas as tabelas. Todos os `GRANT` foram **revogados** de `anon`.
Não existe nenhuma policy para `anon`. Resultado: `GET /rest/v1/bandas` com a anon key
devolve `permission denied`. Não é "devolve vazio" — é "não existe pra você".

### Camada 2 — uma porta só, e ela devolve uma banda só

```sql
public.abrir_camarim(p_chave text) → jsonb   -- SECURITY DEFINER, STABLE
```

É a única função exposta a `anon`. Ela:
- valida o formato da chave antes de tocar no banco (`^[a-z0-9-]+$`, mínimo 8 chars) — corta
  injeção e lixo;
- busca **uma** linha por `chave`, ignorando bandas em `rascunho`;
- devolve `null` se não achar — **não diz** se a banda existe ou se a chave está errada;
- monta o JSON já filtrado: nunca inclui `path_alta`, e os `url_externa` / `downloads` só
  aparecem se `liberado`.

Como o filtro `where chave = p_chave` está **dentro** da função, não existe parâmetro que
faça ela devolver duas bandas. Não há como pedir "todas".

### Camada 3 — o arquivo em alta mora num cofre fechado

Bucket `originais` é **privado**, sem nenhuma policy de leitura para `anon`. Nem listar, nem
ler. O único jeito de tirar um byte de lá é um **link assinado**, que só a Edge Function
emite (ela roda com service_role, do lado do servidor).

Antes de assinar, a função faz:

```ts
.from("fotos").select(...).eq("id", id).eq("banda_id", banda.id)
                                        ^^^^^^^^^^^^^^^^^^^^^^^
```

O `banda_id` vem da chave da URL. Pedir o UUID de uma foto da banda vizinha usando a chave da
Crowns devolve **404** — a linha simplesmente não é encontrada. Testado.

Link assinado vale **1 hora** e é `download: true`.

### Camada 4 — o que é público, é público de propósito

Bucket `previas` é público, mas só tem: capa, fotos **com marca d'água**, cortesias em
resolução de tela e o clipe curto. Se vazar, vazou material de vitrine. É o que a gente quer
que circule.

### Freio contra força bruta
`registra_acesso()` para de gravar log se passar de 300 eventos por minuto — assim ninguém
enche a tabela martelando chaves. As tentativas erradas ficam registradas como
`chave_invalida` para o Alf conseguir ver o padrão.

### Avisos que sobram nos advisors (e são intencionais)
`anon_security_definer_function_executable` em `abrir_camarim` e `registra_acesso`.
**É o desenho.** Essas duas funções *são* a porta de entrada. Elas são `SECURITY DEFINER`
justamente para poderem ler as tabelas que o `anon` não alcança, e cada uma filtra por chave
antes de devolver qualquer coisa. Não "corrigir" revogando o execute — isso derruba o site.

---

## 8. Storage — buckets e convenção de caminhos

| Bucket | Público? | Limite/arquivo | O que vai |
|---|---|---|---|
| `previas` | **sim** | 500 MB | capa, fotos com marca, cortesias em resolução de tela, poster, clipe curto |
| `originais` | **não** | 20 GB | fotos em alta sem marca, vídeos completos, `fotos.zip` |

Convenção de caminho — **sempre prefixado pelo `banda_id`**, para o material de uma banda
nunca encostar no de outra:

```
previas/   <banda_id>/capa.jpg
           <banda_id>/w01.jpg  w02.jpg …      (com marca d'água)
           <banda_id>/c01.jpg  c02.jpg …      (cortesia, limpa, resolução de tela)
           <banda_id>/poster.jpg
           <banda_id>/previa.mp4              (clipe curto, com marca)

originais/ <banda_id>/fotos/f01.jpg  f02.jpg …   (alta, sem marca)
           <banda_id>/videos/v01.mp4 …
           <banda_id>/fotos.zip
```

Policies do Storage:
- `previas_leitura_publica` — SELECT liberado para todo mundo em `previas`.
- `admin_storage` — CRUD completo nos dois buckets, só para `authenticated` que passe em `eh_admin()`.
- `originais` **não tem policy de leitura para anon**. Só link assinado.

---

## 9. Edge Function `camarim` — contrato

```
GET https://hpeyyamwoisehqylrdtx.supabase.co/functions/v1/camarim
```
`verify_jwt: false` (não há login do cliente). A autorização é a própria chave da banda.

| Query | Resposta |
|---|---|
| `?chave=<chave>` <br>`?chave=<chave>&acao=dados` | o JSON completo da página (mesmo payload de `abrir_camarim`) |
| `?chave=<chave>&acao=downloads` | lista de itens com **links assinados** (1 h) |
| `?chave=<chave>&acao=item&id=<uuid>` | link assinado de **um** arquivo |

**Regras que ela aplica:**
- chave fora do padrão → `404 {"erro":"link invalido"}` (sem revelar nada)
- banda em `rascunho` → `404`
- `validade` vencida → `410 {"erro":"link vencido"}`
- foto **cortesia** → assina mesmo sem pagamento
- foto normal ou vídeo, banda não liberada → `403 {"erro":"ainda nao liberado"}`
- item que não pertence àquela banda → `404`
- toda chamada registra em `acessos`

Exemplo de `acao=downloads` com a banda liberada:
```json
{
  "banda": "Crowns",
  "liberado": true,
  "pacote": "Pacote Completo",
  "expira_em": 3600,
  "itens": [
    {"tipo":"foto","id":"…","titulo":"geral.jpg","cortesia":true,"bytes":123,"url":"https://…?token=…"},
    {"tipo":"video","id":"…","titulo":"Música 1 completa","duracao":"4:32","url":"https://…"},
    {"tipo":"link","titulo":"Show completo","tamanho":"4,2 GB","url":"https://drive.google.com/…"}
  ]
}
```

Código-fonte em `supabase/functions/camarim/index.ts`.

---

## 10. O contrato `DADOS` da página da banda

O template `pagina.html` lê `window.DADOS` de um `dados.js` irmão. **O JSON que
`abrir_camarim` devolve foi desenhado para caber nesse formato** — a migração é quase
um plug direto.

```js
window.DADOS = {
  banda, evento, data, local, prazo, validade, whatsapp,
  capa: "capa.jpg", posterVideo: "poster.jpg",
  totalFotos, totalMusicas, resolucao,
  videos: [ {titulo, duracao, arquivo, previa: bool} ],
  sobreVideo,
  fotos: [ {alta:"f01.jpg", marca:"w01.jpg", cortesia: bool} ],
  pacotes: [ {nome, preco, itens:[…]} ],
  creditos: […], equipe: [[rotulo,valor],…],
  liberado: bool, pacoteComprado: "", downloads: [ {titulo,descricao,tamanho,url} ]
};
```

Diferenças do payload novo (renomear no adaptador, não no banco):
- `fotos[].marca` → agora `fotos[].previa` (caminho no bucket público)
- `fotos[].alta` → **sumiu de propósito**. Alta só sai por `acao=item`/`acao=downloads`.
- `videos[].arquivo` vem `null` quando travado, mais um campo `travado: true`.

A página tem dois estados, controlados por `body[data-estado="previa"|"liberado"]`, que
ligam/desligam as classes `.so-previa` / `.so-liberado`.

---

## 11. Estado atual do frontend

### `mesa-de-som.html` — o painel do Alf 🟡 migrado, falta teste com login real
Login por e-mail/senha, upload pro Supabase (fotos + vídeo completo) e botão **Liberar
banda** já implementados (25/08/2026). Interface simplificada: sumiram os campos que eram
iguais pra todas as bandas (evento/data/local/prazo/validade/WhatsApp — viraram constantes);
as 26 bandas já entram pré-cadastradas na primeira vez que abre. O motor antigo (arrastar
fotos, marca d'água em Canvas, redimensionar) foi preservado; o gerador de zip continua
existindo, escondido num painel "Ferramentas de emergência", só para quando o Supabase cair.
**Falta**: alguém com login de admin de verdade testar o fluxo completo uma vez — não dá pra
simular isso num agente porque exigiria digitar a senha real do admin.

### `site/pagina.html` — a página da banda 🟡 conectada ao Supabase, testada com dados sintéticos
Substituiu o antigo `dados.js` estático: lê a chave da URL (`/b/<chave>/` via rewrite da
Vercel, ou `?chave=` direto), busca `acao=dados` na Edge Function, e quando liberado busca
também `acao=downloads` (pra pegar os links assinados das fotos em alta e trocar a grade de
fotos pela versão sem marca). Testada ponta a ponta em 25/08/2026 com uma banda fake inserida
direto no banco (fotos, vídeo, estado normal e liberado) — **passou**. Falta testar com uma
banda de verdade publicada pela Mesa de Som. Decisões de arquitetura tomadas nessa migração,
importantes pra quem mexer nisso depois:
- **Vídeo completo em vez de link do Drive.** O Alf decidiu (25/08/2026) subir o arquivo
  completo de cada música direto no sistema. O vídeo marcado como **prévia** vai pro bucket
  público `previas` (por isso o limite desse bucket subiu pra 20 GB — seção 16) — é o
  **mesmo arquivo** que toca a prévia e que vira o download em alta depois de liberado, sem
  reprocessar nada. Os outros vídeos (não-prévia) continuam no bucket privado `originais`,
  só saem por link assinado depois do pagamento — igual às fotos.
- **Corte da prévia em 30 segundos é feito no player, não no arquivo.** Não existe recorte de
  vídeo de verdade (re-encode) — o `<video>` toca o arquivo completo e um `timeupdate` pausa
  em 30s quando `!liberado`. Decisão consciente: gerar um clipe cortado de verdade no
  navegador exigiria re-encodar (MediaRecorder), o resultado sairia em WebM e **não toca no
  Safari/iPhone** — inaceitável pra esse público. A troca é que um usuário técnico poderia,
  em tese, abrir a URL pública do vídeo direto e ver mais que 30s — risco aceito, porque o
  ativo de valor real (o vídeo em si) já é intencionalmente uma prévia de baixo risco.
- **`capa.jpg` e `poster.jpg` são convenção de caminho fixo, não colunas no banco.**
  A Mesa de Som sempre sobe `previas/<banda_id>/capa.jpg` (hero) e `previas/<banda_id>/poster.jpg`
  (poster do vídeo) nesses nomes exatos; a página monta a URL direto a partir do `id` da banda
  que `abrir_camarim` devolve. Não tem coluna `bandas.capa` — a "capa" de verdade (a foto
  marcada como capa) é só mais uma linha em `fotos`, com `capa:true`.
- **"Baixar tudo" das fotos é um zip montado no navegador do cliente**, não no servidor: a
  página busca cada foto assinada via `acao=downloads`, baixa todas e monta o zip na hora
  com o mesmo escritor de ZIP em JS puro que a Mesa de Som usa (código duplicado de propósito
  — projeto é HTML estático, sem build step pra compartilhar módulo). Funciona bem pra
  dezenas de fotos; **não** foi testado com uma banda de 60+ fotos em alta resolução — pode
  ficar lento. Ver item 5 do backlog.
- O protótipo antigo em `site/b/crowns-x7k92m/` (com `dados.js` estático) foi **mantido só de
  referência histórica** — não é mais o template usado, e não recebe as atualizações daqui
  pra frente.

---

## 12. Backlog para o Claude Code

Em ordem. O item 1 é o que destrava tudo.

### 1. Migrar a Mesa de Som para o Supabase 🟡 falta teste com login real
Ver detalhes na seção 11. O que falta: alguém com acesso de admin de verdade logar, publicar
uma banda de verdade (fotos + vídeo) e clicar em Liberar, uma vez, pra confirmar o fluxo
inteiro.

### 2. Ligar a página da banda no Supabase 🟡 falta teste com uma banda real
Ver detalhes na seção 11 (`site/pagina.html`). Testado com dados sintéticos inseridos direto
no banco; falta confirmar com uma banda publicada pela Mesa de Som de verdade.

### 3. Deploy 🟡
- ✅ `vercel.json` publica somente `site/`, manda `/b/*` pra `pagina.html` sem mudar a URL e
  aplica `X-Robots-Tag: noindex, nofollow, noarchive` em todas as páginas. Localmente,
  `serve.json` replica a rota para testar sem subir nada (`http://localhost:5757/b/<chave>/`).
- ✅ `robots.txt` mantém `Disallow: /`. Os arquivos `_redirects` e `_headers` continuam em
  `site/` apenas para compatibilidade com a Netlify, caso seja necessário voltar.
- Falta: importar o repositório na Vercel e apontar o CNAME
  `camarim.lamusicschool.com.br` no **Registro.br**.

### 4. Cadastro em lote das 26 bandas ✅ feito (parcial)
As 26 bandas entram pré-cadastradas sozinhas na Mesa de Som (local, na primeira vez que abre
— seção 11). **Falta** a banda extra **"Julina Geral"** com `aberta = true` — não foi pedida
ainda, confirmar com o Alf antes de criar.

### 5. Melhorias 🟢
- ✅ Botão "baixar tudo" que monta o zip a partir dos links assinados — feito em
  `site/pagina.html` (seção 11), mas só testado com 2 fotos. Testar/otimizar com uma banda
  de 60+ fotos em alta — pode precisar de uma barra de progresso mais clara ou de baixar em
  paralelo em vez de sequencial.
- Marca d'água nos vídeos de prévia (hoje só as fotos têm). Como o vídeo agora é o arquivo
  completo tocando com corte por tempo (seção 11), isso deixou de ser tão urgente — sem
  watermark, um link vazado mostra o show sem marca, mas só até onde o corte deixar assistir.
- Painel de acessos: quem abriu, quem baixou, quem ainda nem clicou.
- Reavaliar Cloudflare R2 se o storage do Supabase apertar (seção 4).

---

## 13. Identidade visual

Preto, vermelho e branco. Premium, seco, sem enfeite.

```css
--ink:     #0A0708   /* fundo */
--surface: #15100F
--line:    #2C2021
--red:     #E23127   /* o vermelho da marca */
--paper:   #F6F2F0
--text:    #EDE6E4
--muted:   #9C8B88
```

| Papel | Fonte | Fallback |
|---|---|---|
| Display | **Anton** | `'Arial Narrow','DejaVu Sans Condensed',Impact` |
| Corpo | **Archivo** | sans-serif |
| Dados/rótulos | **IBM Plex Mono** | monospace |

Marca d'água: texto branco repetido, rotação **−28°**, corpo `largura × 0,046`,
passo `fonte × 3,0`, opacidade ~0,22. Já foi **aumentada** a pedido do Alf — não diminuir.

---

## 14. Testes já executados

**33 testes contra o Supabase, todos passando.** Resumo do que foi verificado:

| Ataque tentado | Resultado |
|---|---|
| `GET /rest/v1/{bandas,fotos,videos,downloads,acessos,admins}` com anon key | `permission denied` nas 6 |
| `INSERT` de banda com anon key | bloqueado |
| `PATCH liberado=true` com anon key | bloqueado |
| `abrir_camarim` com chave errada, chave sem token, `' or 1=1--` | `null` em todas |
| chave da banda vizinha | devolve só a vizinha, nada da Crowns |
| payload contém `path_alta` ou link do Drive antes de pagar | **não** |
| link assinado adulterado (`token=INVALIDO`) | recusado |
| `acao=item` com UUID de foto de **outra** banda, usando a chave da Crowns | `404` |
| Crowns já liberada tentando pegar foto da vizinha | `404` |
| foto não-cortesia antes do pagamento | `403` |
| `GET /storage/v1/object/public/originais/…` | recusado |
| listar o bucket `originais` | recusado |
| liberar a Crowns → a vizinha pegou carona? | **não**, continua `liberado:false` |
| login dos dois admins + `eh_admin()` + criar banda | OK nos dois |

Testes anteriores do frontend: 39 nos protótipos, 18 no site real, 21 na Mesa de Som
mesclada, 15 na geração em lote, 6 no tratamento de vídeo — todos passando.

---

## 15. Runbook do Alf

**Subir uma banda**
1. Abrir a Mesa de Som e entrar com o e-mail e senha.
2. Criar a banda, informar o total de fotos.
3. Arrastar as fotos. Marcar a **capa** (a foto geral) e 3–4 **cortesias** — de preferência
   uma de cada integrante.
4. Vídeo: **prévia curta** (40–60 s) → *enviar o arquivo*. **Vídeo completo** → *link do Drive*.
5. Publicar. Copiar o link e mandar no WhatsApp da banda.

**Liberar depois do pagamento**
Abrir a banda na Mesa de Som → **Liberar** → escolher o pacote. Pronto, sem deploy.

**Regra dos vídeos — a que mais confunde**
> Link do Google Drive **não toca** no player. O Drive devolve uma página, não o arquivo.
> Drive serve só para o **botão de baixar**.
> A prévia que toca na página tem que ser **arquivo enviado**.

---

## 16. Armadilhas conhecidas — já custaram tempo

| Armadilha | O que fazer |
|---|---|
| **service_role / `sbp_` no frontend** | Nunca. Só a anon key vai pro navegador. |
| Link do Drive no `<video>` | Não funciona. Drive só para download. |
| `gera_token` sem GRANT | O default de `bandas.token` chama a função; sem `execute` para `authenticated`, o admin toma `permission denied` ao criar banda. Já corrigido — não revogar. |
| `</script>` dentro de template embutido | Escapar como `<\/script` ao injetar. |
| `padding` shorthand no mobile | `.hero-in{padding:130px 0}` atropela o `padding: 0 var(--gut)` do `.wrap` e cola o texto na borda. Usar só `padding-top`/`padding-bottom`. |
| Regex de diacríticos | Escrever `/[\u0300-\u036f]/g`. A forma literal quebra na codificação. |
| `id` duplicado | `getElementById("creditos")` pegava a `<section>` e limpava tudo. Ids únicos. |
| Fonte display | Anton, com fallback. "Big Shoulders Display" não é confiável. |
| Quebra do nome da banda no hero | Envolver **cada palavra** em `<span class="w">` com `white-space:nowrap`. |
| Uma prévia por banda | Índice único parcial no banco. Marcar `previa` num vídeo só. |
| Advisors `security_definer_executable` | Intencionais em `abrir_camarim` e `registra_acesso`. Não "corrigir". |
| `supabase db push` quebrado nesse projeto | Todas as migrations usam o mesmo prefixo de data (`20260825_000N_nome.sql`). O CLI extrai só a parte numérica antes do primeiro `_` como "versão" — como todas compartilham `20260825`, ele tenta reinserir a mesma versão no histórico e quebra com `duplicate key … schema_migrations_pkey`. Enquanto isso não for corrigido (precisaria renomear os arquivos com timestamp completo, ex. `20260825000100_schema.sql`), aplique mudanças de schema direto via SQL (Management API ou painel do Supabase) e registre um arquivo em `supabase/migrations/` só como documentação — não confie em `db push` pra sincronizar. Foi assim que o limite do bucket `previas` foi elevado pra 20 GB em 25/08/2026. |

---

## 17. Arquivos entregues

```
CAMARIM.md                              este documento
supabase/
  migrations/
    20260825_0001_schema.sql            tabelas, tipos, triggers, índices
    20260825_0002_buckets.sql           previas (público) / originais (privado)
    20260825_0003_rls.sql               RLS, abrir_camarim, policies de storage
    20260825_0004_ajustes.sql           search_path, freio de log, limpeza
    20260825_0005_admin.sql             allowlist de admin + grant do gera_token
  functions/
    camarim/index.ts                    Edge Function de download
```

Já aplicadas no projeto `hpeyyamwoisehqylrdtx`. Se o Claude Code rodar
`supabase db push` num ambiente limpo, elas reconstroem o banco inteiro do zero.

O frontend (`pagina.html`, `mesa-de-som.html`, a pasta `site/`) vai no outro pacote.

---

*Camarim — LA Music · Julina Rock Fest 2026*
