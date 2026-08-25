-- ============================================================
--  Quem pode entrar na Mesa de Som
--  Basta criar o usuário no painel do Supabase (Authentication
--  -> Add user) com um e-mail da lista abaixo: ele vira admin
--  sozinho, sem precisar rodar mais nada.
-- ============================================================

create table if not exists public.admins_permitidos (
  email text primary key
);
alter table public.admins_permitidos enable row level security;
revoke all on public.admins_permitidos from anon, authenticated;

insert into public.admins_permitidos (email) values
  ('lucianoalf.la@gmail.com')
on conflict do nothing;

create or replace function public.promove_admin()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if exists (select 1 from public.admins_permitidos p
              where lower(p.email) = lower(new.email)) then
    insert into public.admins (user_id, nome)
    values (new.id, coalesce(new.raw_user_meta_data->>'nome', new.email))
    on conflict (user_id) do nothing;
  end if;
  return new;
end $$;

drop trigger if exists trg_promove_admin on auth.users;
create trigger trg_promove_admin after insert on auth.users
for each row execute function public.promove_admin();

-- quem já existir e estiver na lista entra agora
insert into public.admins (user_id, nome)
select u.id, coalesce(u.raw_user_meta_data->>'nome', u.email)
  from auth.users u
  join public.admins_permitidos p on lower(p.email) = lower(u.email)
on conflict (user_id) do nothing;


insert into public.admins_permitidos (email) values
  ('lucianoalf.la@gmail.com'),
  ('yuristanzi@gmail.com')
on conflict do nothing;

-- o default de bandas.token chama gera_token; o admin precisa poder executar
grant execute on function public.gera_token(int) to authenticated;
