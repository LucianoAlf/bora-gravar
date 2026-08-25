-- ============================================================
--  CAMARIM / BORA GRAVAR  —  schema base
-- ============================================================

create extension if not exists pgcrypto;

-- ------------------------------------------------------------
-- quem é administrador (o Alf e quem ele autorizar)
-- ------------------------------------------------------------
create table if not exists public.admins (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  nome       text,
  criado_em  timestamptz not null default now()
);

create or replace function public.eh_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select exists (select 1 from public.admins a where a.user_id = auth.uid());
$$;

-- ------------------------------------------------------------
-- token aleatório (endereço secreto da banda)
-- ------------------------------------------------------------
create or replace function public.gera_token(n int default 12)
returns text
language sql
volatile
as $$
  select string_agg(
           substr('abcdefghijkmnpqrstuvwxyz23456789',
                  1 + floor(random()*32)::int, 1), '')
  from generate_series(1, n);
$$;

-- ------------------------------------------------------------
-- BANDAS
-- ------------------------------------------------------------
do $$ begin
  create type public.estado_banda as enum ('rascunho','publicada','liberada');
exception when duplicate_object then null; end $$;

create table if not exists public.bandas (
  id              uuid primary key default gen_random_uuid(),

  nome            text not null,
  slug            text not null,
  token           text not null default public.gera_token(12),
  chave           text generated always as (slug || '-' || token) stored,

  evento          text not null default 'Julina Rock Fest 2026',
  data_evento     date,
  local           text,
  prazo           date,
  validade        date,
  whatsapp        text not null default '5521982583946',

  total_fotos     int  not null default 0,
  total_musicas   int  not null default 0,
  resolucao       text,
  sobre_video     text,

  pacotes         jsonb not null default '[]'::jsonb,
  creditos        jsonb not null default '[]'::jsonb,
  equipe          jsonb not null default '[]'::jsonb,

  estado          public.estado_banda not null default 'rascunho',
  aberta          boolean not null default false,   -- página aberta: tudo cortesia, sem venda
  liberado        boolean not null default false,   -- pagou: libera alta resolução
  pacote_comprado text,
  valor           numeric(10,2),
  liberada_em     timestamptz,

  criado_em       timestamptz not null default now(),
  atualizado_em   timestamptz not null default now()
);

create unique index if not exists bandas_slug_uk  on public.bandas (slug);
create unique index if not exists bandas_chave_uk on public.bandas (chave);

-- ------------------------------------------------------------
-- FOTOS
-- ------------------------------------------------------------
create table if not exists public.fotos (
  id            uuid primary key default gen_random_uuid(),
  banda_id      uuid not null references public.bandas(id) on delete cascade,

  ordem         int  not null default 0,
  nome_original text,

  -- o que aparece na página (bucket PÚBLICO "previas")
  --   foto normal  -> versão com marca d'água
  --   cortesia     -> versão limpa em resolução de tela
  path_previa   text not null,

  -- o arquivo em alta, sem marca (bucket PRIVADO "originais")
  path_alta     text,

  cortesia      boolean not null default false,
  capa          boolean not null default false,

  largura       int,
  altura        int,
  bytes         bigint,

  criado_em     timestamptz not null default now()
);

create index if not exists fotos_banda_idx on public.fotos (banda_id, ordem);
-- só uma capa por banda
create unique index if not exists fotos_capa_uk
  on public.fotos (banda_id) where capa;

-- a capa é sempre cortesia
create or replace function public.capa_e_cortesia()
returns trigger language plpgsql as $$
begin
  if new.capa then new.cortesia := true; end if;
  return new;
end $$;

drop trigger if exists trg_capa_cortesia on public.fotos;
create trigger trg_capa_cortesia before insert or update on public.fotos
for each row execute function public.capa_e_cortesia();

-- ------------------------------------------------------------
-- VÍDEOS
-- ------------------------------------------------------------
create table if not exists public.videos (
  id           uuid primary key default gen_random_uuid(),
  banda_id     uuid not null references public.bandas(id) on delete cascade,

  ordem        int  not null default 0,
  titulo       text not null default 'Vídeo',
  duracao      text,

  previa       boolean not null default false,  -- o único que toca antes de pagar

  path_previa  text,   -- clipe curto com marca (bucket PÚBLICO)
  path_alta    text,   -- vídeo completo (bucket PRIVADO)
  url_externa  text,   -- ou link de fora (Drive), revelado só depois de liberar
  poster_path  text,

  bytes        bigint,
  criado_em    timestamptz not null default now()
);

create index if not exists videos_banda_idx on public.videos (banda_id, ordem);
create unique index if not exists videos_previa_uk
  on public.videos (banda_id) where previa;

-- ------------------------------------------------------------
-- DOWNLOADS avulsos (links de fora)
-- ------------------------------------------------------------
create table if not exists public.downloads (
  id         uuid primary key default gen_random_uuid(),
  banda_id   uuid not null references public.bandas(id) on delete cascade,
  ordem      int  not null default 0,
  titulo     text not null,
  descricao  text,
  tamanho    text,
  url        text not null,
  criado_em  timestamptz not null default now()
);

create index if not exists downloads_banda_idx on public.downloads (banda_id, ordem);

-- ------------------------------------------------------------
-- LOG de acessos (quem abriu / quem baixou)
-- ------------------------------------------------------------
create table if not exists public.acessos (
  id         bigserial primary key,
  banda_id   uuid references public.bandas(id) on delete set null,
  chave      text,
  tipo       text not null,           -- 'abriu' | 'baixou' | 'chave_invalida'
  detalhe    text,
  ip         text,
  agente     text,
  criado_em  timestamptz not null default now()
);

create index if not exists acessos_banda_idx on public.acessos (banda_id, criado_em desc);
create index if not exists acessos_tipo_idx  on public.acessos (tipo, criado_em desc);

-- ------------------------------------------------------------
-- atualizado_em
-- ------------------------------------------------------------
create or replace function public.toca_atualizado_em()
returns trigger language plpgsql as $$
begin new.atualizado_em := now(); return new; end $$;

drop trigger if exists trg_bandas_atualizado on public.bandas;
create trigger trg_bandas_atualizado before update on public.bandas
for each row execute function public.toca_atualizado_em();

-- marca a data quando a banda é liberada
create or replace function public.marca_liberacao()
returns trigger language plpgsql as $$
begin
  if new.liberado and not coalesce(old.liberado,false) then
    new.liberada_em := now();
    new.estado := 'liberada';
  end if;
  return new;
end $$;

drop trigger if exists trg_liberacao on public.bandas;
create trigger trg_liberacao before update on public.bandas
for each row execute function public.marca_liberacao();
