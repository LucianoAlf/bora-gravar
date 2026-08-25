-- search_path fixo em todas as funções
alter function public.gera_token(int)        set search_path = pg_catalog, public;
alter function public.capa_e_cortesia()      set search_path = pg_catalog, public;
alter function public.toca_atualizado_em()   set search_path = pg_catalog, public;
alter function public.marca_liberacao()      set search_path = pg_catalog, public;

-- freio contra alguém ficar martelando chaves aleatórias:
-- passou de 30 tentativas erradas no último minuto, para de gravar log
create or replace function public.registra_acesso(p_chave text, p_tipo text, p_detalhe text default null)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare v_id uuid; v_n int;
begin
  if p_tipo not in ('abriu','baixou','chave_invalida') then return; end if;

  select count(*) into v_n
    from public.acessos
   where criado_em > now() - interval '1 minute';
  if v_n > 300 then return; end if;

  select id into v_id from public.bandas where chave = p_chave;

  insert into public.acessos (banda_id, chave, tipo, detalhe)
  values (v_id, left(coalesce(p_chave,''),80), p_tipo, left(coalesce(p_detalhe,''),200));
end $$;

revoke all on function public.registra_acesso(text,text,text) from public;
grant execute on function public.registra_acesso(text,text,text) to anon, authenticated;

-- limpeza automática do log (90 dias)
create or replace function public.limpa_acessos()
returns void language sql security definer
set search_path = pg_catalog, public as $$
  delete from public.acessos where criado_em < now() - interval '90 days';
$$;
revoke all on function public.limpa_acessos() from public, anon, authenticated;

create index if not exists acessos_recentes_idx on public.acessos (criado_em desc);
drop index if exists public.acessos_banda_idx;
create index if not exists acessos_banda_idx on public.acessos (banda_id, criado_em desc);
