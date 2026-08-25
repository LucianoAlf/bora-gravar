-- ============================================================
--  BUCKETS
--  previas   -> PÚBLICO  (capa, fotos com marca, cortesias, clipe curto)
--  originais -> PRIVADO  (fotos em alta e vídeos completos)
-- ============================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('previas','previas', true,  524288000,
     array['image/jpeg','image/png','image/webp','video/mp4','video/quicktime']),
  ('originais','originais', false, 21474836480,
     array['image/jpeg','image/png','image/webp','image/tiff',
           'video/mp4','video/quicktime','application/zip'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;
