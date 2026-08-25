-- ============================================================
--  Vídeo por pacote: cada categoria de vídeo só libera com o
--  pacote certo, e uma banda pode ter mais de um vídeo com prévia.
--
--  Combinado com o Yuri em 25/08/2026:
--  - "Melhores momentos" (R$300) libera só o vídeo categoria
--    'melhores_momentos'.
--  - "2 músicas completas" (R$500) libera só os vídeos categoria
--    'completa'.
--  - "Pacote completo" (R$700) libera tudo — vídeos e fotos em alta.
--  - Fotos em alta só saem no Pacote completo, nunca nos outros dois
--    (regra que já valia na página de vendas, agora também no banco).
-- ============================================================

alter table public.videos
  add column if not exists categoria text
    check (categoria in ('melhores_momentos','completa'));

-- antes só podia ter 1 vídeo marcado como prévia por banda; agora o
-- Alf pode marcar vários (cada um mostra seu próprio recorte de 30s).
drop index if exists videos_previa_uk;

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
  v_fotos_ok boolean;
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
  v_fotos_ok := b.aberta or (b.liberado and coalesce(b.pacote_comprado,'') = 'Pacote completo');

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
    'fotosDesbloqueadas', v_fotos_ok,
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
               -- o clipe de prévia toca sempre (a página corta em 30s
               -- enquanto não desbloquear); o resto só depois de liberar
               -- o pacote que corresponde à categoria deste vídeo
               'arquivo', case when v.previa then v.path_previa else null end,
               'desbloqueado', coalesce(b.aberta or (v_lib and (
                 coalesce(b.pacote_comprado,'') = 'Pacote completo'
                 or (coalesce(b.pacote_comprado,'') = 'Melhores momentos' and coalesce(v.categoria,'') = 'melhores_momentos')
                 or (coalesce(b.pacote_comprado,'') = '2 músicas completas' and coalesce(v.categoria,'') = 'completa')
               )), false),
               'poster',  v.poster_path,
               'travado', not coalesce(v.previa or (b.aberta or (v_lib and (
                 coalesce(b.pacote_comprado,'') = 'Pacote completo'
                 or (coalesce(b.pacote_comprado,'') = 'Melhores momentos' and coalesce(v.categoria,'') = 'melhores_momentos')
                 or (coalesce(b.pacote_comprado,'') = '2 músicas completas' and coalesce(v.categoria,'') = 'completa')
               ))), false)
             ) order by v.ordem, v.criado_em)
        from public.videos v where v.banda_id = b.id), '[]'::jsonb),

    -- links de fora só aparecem depois de liberado (qualquer pacote)
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
