-- ============================================================
--  Aumenta o limite de tamanho do bucket "previas"
--
--  Antes: 500 MB — pensado só pra fotos e um clipe curto.
--  Agora: o vídeo completo de cada música sobe pro bucket público
--  (é o mesmo arquivo que toca a prévia de 30s e, depois de liberado,
--  vira o download em alta). Um show inteiro em boa qualidade passa
--  fácil de 500 MB, então o limite sobe pra bater com o do bucket
--  "originais".
-- ============================================================

update storage.buckets
   set file_size_limit = 21474836480  -- 20 GB
 where id = 'previas';
