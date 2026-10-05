-- ============================================================
--  CAMARIM BORA GRAVAR — plataforma padrao de entregas
--
--  A estrutura antiga do Julina (bandas/fotos/videos) continua
--  intacta. Estes objetos novos atendem eventos futuros e podem
--  conviver com o Julina durante a migracao gradual.
-- ============================================================

create table if not exists public.eventos (
  id                  uuid primary key default gen_random_uuid(),
  nome                text not null check (char_length(nome) between 2 and 160),
  slug                text not null unique check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  descricao           text,
  data_evento         date,
  local               text,
  whatsapp            text not null default '5521982583946',
  tipo_participante   text not null default 'aluno'
    check (tipo_participante in ('aluno','familia','banda','grupo')),
  politica_liberacao  text not null default 'manual'
    check (politica_liberacao in ('manual','ao_pagar')),
  ativo               boolean not null default true,
  criado_em           timestamptz not null default now(),
  atualizado_em       timestamptz not null default now()
);

create table if not exists public.entregas (
  id                  uuid primary key default gen_random_uuid(),
  evento_id           uuid not null references public.eventos(id) on delete cascade,
  titulo              text not null check (char_length(titulo) between 1 and 160),
  slug                text not null check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  token               text not null default public.gera_token(16),
  chave               text generated always as (slug || '-' || token) stored,
  crm_id              text,
  responsavel_nome    text not null default '',
  responsavel_telefone text not null default '',
  unidade             text not null default '',
  contrato            text not null default 'unknown'
    check (contrato in ('unknown','yes','no')),
  pagamento           text not null default 'unknown'
    check (pagamento in ('unknown','pending','paid')),
  origem              text not null default 'manual'
    check (origem in ('manual','crm')),
  origem_atualizada_em timestamptz,
  estado              text not null default 'rascunho'
    check (estado in ('rascunho','publicada','liberada','arquivada')),
  liberado            boolean not null default false,
  liberada_em         timestamptz,
  validade            date,
  criado_em           timestamptz not null default now(),
  atualizado_em       timestamptz not null default now(),
  unique (chave)
);

create unique index if not exists entregas_evento_crm_uk
  on public.entregas (evento_id, crm_id)
  where crm_id is not null;
create index if not exists entregas_evento_estado_idx
  on public.entregas (evento_id, estado, atualizado_em desc);

create table if not exists public.entrega_participantes (
  id          uuid primary key default gen_random_uuid(),
  entrega_id  uuid not null references public.entregas(id) on delete cascade,
  crm_id      text,
  nome        text not null check (char_length(nome) between 1 and 160),
  unidade     text not null default '',
  foto_url    text not null default '',
  ordem       int not null default 0,
  criado_em   timestamptz not null default now()
);

create unique index if not exists entrega_participantes_crm_uk
  on public.entrega_participantes (entrega_id, crm_id)
  where crm_id is not null;
create index if not exists entrega_participantes_entrega_idx
  on public.entrega_participantes (entrega_id, ordem);

create table if not exists public.entrega_midias (
  id            uuid primary key default gen_random_uuid(),
  entrega_id    uuid not null references public.entregas(id) on delete cascade,
  tipo          text not null check (tipo in ('foto','video','arquivo')),
  titulo        text not null default 'Arquivo',
  path_original text not null,
  path_previa   text,
  poster_path   text,
  mime_type     text,
  bytes         bigint,
  largura       int,
  altura        int,
  duracao       numeric(10,2),
  ordem         int not null default 0,
  criado_em     timestamptz not null default now()
);

create index if not exists entrega_midias_entrega_idx
  on public.entrega_midias (entrega_id, ordem, criado_em);

create table if not exists public.entrega_acessos (
  id          bigserial primary key,
  entrega_id  uuid references public.entregas(id) on delete set null,
  chave       text,
  tipo        text not null check (tipo in ('abriu','baixou','chave_invalida')),
  detalhe     text,
  criado_em   timestamptz not null default now()
);

create index if not exists entrega_acessos_entrega_idx
  on public.entrega_acessos (entrega_id, criado_em desc);

create or replace function public.toca_evento_atualizado_em()
returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin new.atualizado_em := now(); return new; end $$;

drop trigger if exists trg_eventos_atualizado on public.eventos;
create trigger trg_eventos_atualizado before update on public.eventos
for each row execute function public.toca_evento_atualizado_em();

create or replace function public.toca_entrega_atualizado_em()
returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  new.atualizado_em := now();
  if new.liberado and not coalesce(old.liberado, false) then
    new.liberada_em := now();
    new.estado := 'liberada';
  elsif not new.liberado and coalesce(old.liberado, false) and new.estado = 'liberada' then
    new.liberada_em := null;
    new.estado := 'publicada';
  end if;
  return new;
end $$;

drop trigger if exists trg_entregas_atualizado on public.entregas;
create trigger trg_entregas_atualizado before update on public.entregas
for each row execute function public.toca_entrega_atualizado_em();

-- Todas as tabelas ficam invisiveis para visitantes. O publico passa
-- apenas pela Edge Function entrega, que valida uma chave por vez.
alter table public.eventos enable row level security;
alter table public.entregas enable row level security;
alter table public.entrega_participantes enable row level security;
alter table public.entrega_midias enable row level security;
alter table public.entrega_acessos enable row level security;
alter table public.eventos force row level security;
alter table public.entregas force row level security;
alter table public.entrega_participantes force row level security;
alter table public.entrega_midias force row level security;

revoke all on public.eventos, public.entregas, public.entrega_participantes,
  public.entrega_midias, public.entrega_acessos from anon, authenticated;

grant select, insert, update, delete on public.eventos, public.entregas,
  public.entrega_participantes, public.entrega_midias to authenticated;
grant select on public.entrega_acessos to authenticated;

do $$
declare t text;
begin
  foreach t in array array['eventos','entregas','entrega_participantes','entrega_midias'] loop
    execute format('drop policy if exists admin_tudo on public.%I', t);
    execute format($f$
      create policy admin_tudo on public.%I
        for all to authenticated
        using ((select public.eh_admin()))
        with check ((select public.eh_admin()))
    $f$, t);
  end loop;
end $$;

drop policy if exists admin_le_entrega_acessos on public.entrega_acessos;
create policy admin_le_entrega_acessos on public.entrega_acessos
  for select to authenticated using ((select public.eh_admin()));

-- Um bucket privado para todos os eventos novos. A pasta sempre começa
-- por evento_id/entrega_id para impedir mistura acidental de materiais.
insert into storage.buckets (id, name, public, file_size_limit)
values ('entregas', 'entregas', false, 21474836480)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit;

drop policy if exists admin_entregas_storage on storage.objects;
create policy admin_entregas_storage on storage.objects
  for all to authenticated
  using (bucket_id = 'entregas' and (select public.eh_admin()))
  with check (bucket_id = 'entregas' and (select public.eh_admin()));

-- Evento inicial. Os contratados entram depois pela consulta privada ao CRM.
insert into public.eventos (
  nome, slug, descricao, tipo_participante, politica_liberacao, ativo
) values (
  'Vocal Kids Sandy e Junior',
  'vocal-kids-sandy-junior',
  'Entrega individual de fotos e videos do evento Vocal Kids.',
  'aluno',
  'manual',
  true
)
on conflict (slug) do nothing;
