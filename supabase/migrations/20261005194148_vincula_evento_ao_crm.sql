-- A origem comercial pertence ao evento, não à plataforma inteira.
-- Assim, eventos futuros não recebem por engano os contratantes do Vocal Kids.
alter table public.eventos
  add column if not exists integracao text not null default 'manual';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'eventos_integracao_check'
      and conrelid = 'public.eventos'::regclass
  ) then
    alter table public.eventos
      add constraint eventos_integracao_check
      check (integracao in ('manual', 'vocal_kids_crm'));
  end if;
end $$;

update public.eventos
set integracao = 'vocal_kids_crm'
where slug = 'vocal-kids-sandy-junior';
