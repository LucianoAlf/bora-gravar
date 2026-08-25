-- ============================================================
--  RLS  —  a regra de ouro:
--  o visitante (anon) NÃO enxerga tabela nenhuma.
--  Ele só chega no material através da função abrir_camarim(chave),
--  que devolve UMA banda e só a banda daquela chave.
-- ============================================================

alter table public.bandas    enable row level security;
alter table public.fotos     enable row level security;
alter table public.videos    enable row level security;
alter table public.downloads enable row level security;
alter table public.acessos   enable row level security;
alter table public.admins    enable row level security;

alter table public.bandas    force row level security;
alter table public.fotos     force row level security;
alter table public.videos    force row level security;
alter table public.downloads force row level security;

-- tira qualquer permissão herdada
revoke all on public.bandas, public.fotos, public.videos,
              public.downloads, public.acessos, public.admins
  from anon, authenticated;

-- ------------------------------------------------------------
-- ADMIN (o Alf, logado) enxerga e mexe em tudo
-- ------------------------------------------------------------
grant select, insert, update, delete
  on public.bandas, public.fotos, public.videos, public.downloads
  to authenticated;
grant select on public.acessos to authenticated;
grant select on public.admins  to authenticated;

do $$
declare t text;
begin
  foreach t in array array['bandas','fotos','videos','downloads'] loop
    execute format('drop policy if exists admin_tudo on public.%I', t);
    execute format($f$
      create policy admin_tudo on public.%I
        for all to authenticated
        using (public.eh_admin())
        with check (public.eh_admin())
    $f$, t);
  end loop;
end $$;

drop policy if exists admin_le_acessos on public.acessos;
create policy admin_le_acessos on public.acessos
  for select to authenticated using (public.eh_admin());

drop policy if exists admin_le_admins on public.admins;
create policy admin_le_admins on public.admins
  for select to authenticated using (public.eh_admin());

-- ------------------------------------------------------------
-- ANON: nenhuma policy. Nada. Zero linhas, em qualquer tabela.
-- ------------------------------------------------------------

-- ============================================================
--  A PORTA DE ENTRADA DA BANDA
-- ============================================================
create or replace function public.abrir_camarim(p_chave text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_catalog
as $$
declare
  b public.bandas%rowtype;
  v_lib boolean;
  j jsonb;
begin
  -- chave malformada nem chega no banco
  if p_chave is null or length(p_chave) < 8 or p_chave !~ '^[a-z0-9-]+$' then
    return null;
  end if;

  select * into b
    from public.bandas
   where chave = p_chave
     and estado <> 'rascunho';

  if not found then
    return null;                       -- não diz se a banda existe ou não
  end if;

  v_lib := b.liberado or b.aberta;

  j := jsonb_build_object(
    'id',            b.id,
    'banda',         b.nome,
    'chave',         b.chave,
    'evento',        b.evento,
    'data',          b.data_evento,
    'local',         b.local,
    'prazo',         b.prazo,
    'validade',      b.validade,
    'whatsapp',      b.whatsapp,
    'totalFotos',    b.total_fotos,
    'totalMusicas',  b.total_musicas,
    'resolucao',     b.resolucao,
    'sobreVideo',    b.sobre_video,
    'pacotes',       b.pacotes,
    'creditos',      b.creditos,
    'equipe',        b.equipe,
    'aberta',        b.aberta,
    'liberado',      v_lib,
    'pacoteComprado', coalesce(b.pacote_comprado,''),

    'fotos', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id',       f.id,
               'previa',   f.path_previa,       -- caminho no bucket público
               'cortesia', (f.cortesia or b.aberta),
               'capa',     f.capa
             ) order by f.ordem, f.criado_em)
        from public.fotos f where f.banda_id = b.id), '[]'::jsonb),

    'videos', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id',      v.id,
               'titulo',  v.titulo,
               'duracao', v.duracao,
               'previa',  v.previa,
               -- o clipe curto toca sempre; o resto só depois de liberar
               'arquivo', case when v.previa or v_lib then v.path_previa else null end,
               'poster',  v.poster_path,
               'travado', not (v.previa or v_lib)
             ) order by v.ordem, v.criado_em)
        from public.videos v where v.banda_id = b.id), '[]'::jsonb),

    -- links de fora só aparecem depois de liberado
    'downloads', case when v_lib then coalesce((
      select jsonb_agg(jsonb_build_object(
               'titulo',    d.titulo,
               'descricao', d.descricao,
               'tamanho',   d.tamanho,
               'url',       d.url
             ) order by d.ordem, d.criado_em)
        from public.downloads d where d.banda_id = b.id), '[]'::jsonb)
      else '[]'::jsonb end
  );

  return j;
end $$;

revoke all on function public.abrir_camarim(text) from public;
grant execute on function public.abrir_camarim(text) to anon, authenticated;

-- registra a visita (não devolve nada, não dá pra ler)
create or replace function public.registra_acesso(p_chave text, p_tipo text, p_detalhe text default null)
returns void
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare v_id uuid;
begin
  if p_tipo not in ('abriu','baixou','chave_invalida') then return; end if;
  select id into v_id from public.bandas where chave = p_chave;
  insert into public.acessos (banda_id, chave, tipo, detalhe)
  values (v_id, left(coalesce(p_chave,''),80), p_tipo, left(coalesce(p_detalhe,''),200));
end $$;

revoke all on function public.registra_acesso(text,text,text) from public;
grant execute on function public.registra_acesso(text,text,text) to anon, authenticated;

-- as outras funções internas não ficam expostas
revoke all on function public.gera_token(int) from public, anon, authenticated;
revoke all on function public.eh_admin() from public, anon;
grant execute on function public.eh_admin() to authenticated;

-- ============================================================
--  STORAGE
-- ============================================================
drop policy if exists previas_leitura_publica on storage.objects;
create policy previas_leitura_publica on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'previas');

drop policy if exists admin_storage on storage.objects;
create policy admin_storage on storage.objects
  for all to authenticated
  using (bucket_id in ('previas','originais') and public.eh_admin())
  with check (bucket_id in ('previas','originais') and public.eh_admin());

-- bucket "originais": NENHUMA policy de leitura para anon.
-- O único caminho é o link assinado que a Edge Function emite.
