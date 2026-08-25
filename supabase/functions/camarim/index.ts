// ============================================================
//  camarim  —  entrega dos arquivos em alta
//
//  GET /camarim?chave=crowns-x7k92m            -> dados da página
//  GET /camarim?chave=...&acao=downloads       -> links assinados
//  GET /camarim?chave=...&acao=item&id=<uuid>  -> link de 1 arquivo
//
//  A chave é o único endereço. Sem chave, nada sai daqui.
//  Um link assinado só é emitido para arquivos DAQUELA banda.
// ============================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const URL_SB = Deno.env.get("SUPABASE_URL")!;
const CHAVE_SERVICO = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const VALIDADE = 60 * 60; // 1 hora

const db = createClient(URL_SB, CHAVE_SERVICO, { auth: { persistSession: false } });
const URL_PREVIAS = `${URL_SB}/storage/v1/object/public/previas/`;

// vídeo "prévia": o arquivo completo mora no bucket público (previas), sem
// path_alta — o download em alta é o mesmo arquivo público, sem precisar assinar.
function urlVideo(video: { path_alta: string | null; url_externa: string | null; path_previa: string | null }) {
  if (video.path_alta) return assina(video.path_alta);
  if (video.url_externa) return Promise.resolve(video.url_externa);
  if (video.path_previa) return Promise.resolve(URL_PREVIAS + video.path_previa);
  return Promise.resolve(null);
}

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

const resposta = (corpo: unknown, status = 200) =>
  new Response(JSON.stringify(corpo), {
    status,
    headers: { ...CORS, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });

const CHAVE_OK = /^[a-z0-9]+(?:-[a-z0-9]+)+$/;

async function assina(path: string | null) {
  if (!path) return null;
  const { data, error } = await db.storage.from("originais").createSignedUrl(path, VALIDADE, {
    download: true,
  });
  if (error) return null;
  return data.signedUrl;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "GET") return resposta({ erro: "metodo" }, 405);

  const u = new URL(req.url);
  const chave = (u.searchParams.get("chave") ?? "").trim().toLowerCase();
  const acao = u.searchParams.get("acao") ?? "dados";

  if (!CHAVE_OK.test(chave) || chave.length < 8 || chave.length > 120) {
    return resposta({ erro: "link invalido" }, 404);
  }

  // ---- acha a banda (uma só, pela chave) ----
  const { data: banda } = await db
    .from("bandas")
    .select("id, nome, chave, estado, liberado, aberta, pacote_comprado, validade")
    .eq("chave", chave)
    .neq("estado", "rascunho")
    .maybeSingle();

  if (!banda) {
    await db.rpc("registra_acesso", { p_chave: chave, p_tipo: "chave_invalida" });
    return resposta({ erro: "link invalido" }, 404);
  }

  // link vencido
  if (banda.validade && new Date(banda.validade + "T23:59:59Z") < new Date()) {
    return resposta({ erro: "link vencido", validade: banda.validade }, 410);
  }

  const liberado = banda.liberado || banda.aberta;

  // ---- só os dados da página ----
  if (acao === "dados") {
    const { data } = await db.rpc("abrir_camarim", { p_chave: chave });
    if (!data) return resposta({ erro: "link invalido" }, 404);
    await db.rpc("registra_acesso", { p_chave: chave, p_tipo: "abriu" });
    return resposta(data);
  }

  // ---- um arquivo específico ----
  if (acao === "item") {
    const id = u.searchParams.get("id") ?? "";
    if (!/^[0-9a-f-]{36}$/i.test(id)) return resposta({ erro: "item invalido" }, 400);

    // ATENÇÃO: o filtro por banda_id é o que impede pegar arquivo de outra banda
    const { data: foto } = await db
      .from("fotos")
      .select("id, path_alta, cortesia")
      .eq("id", id)
      .eq("banda_id", banda.id)
      .maybeSingle();

    if (foto) {
      if (!liberado && !foto.cortesia) return resposta({ erro: "ainda nao liberado" }, 403);
      const url = await assina(foto.path_alta);
      if (!url) return resposta({ erro: "arquivo indisponivel" }, 404);
      await db.rpc("registra_acesso", { p_chave: chave, p_tipo: "baixou", p_detalhe: "foto " + id });
      return resposta({ url, expira_em: VALIDADE });
    }

    const { data: video } = await db
      .from("videos")
      .select("id, path_alta, url_externa, path_previa, previa")
      .eq("id", id)
      .eq("banda_id", banda.id)
      .maybeSingle();

    if (video) {
      if (!liberado) return resposta({ erro: "ainda nao liberado" }, 403);
      const url = await urlVideo(video);
      if (!url) return resposta({ erro: "arquivo indisponivel" }, 404);
      await db.rpc("registra_acesso", { p_chave: chave, p_tipo: "baixou", p_detalhe: "video " + id });
      return resposta({ url, expira_em: VALIDADE });
    }

    return resposta({ erro: "item invalido" }, 404);
  }

  // ---- a lista de downloads da banda ----
  if (acao === "downloads") {
    const itens: unknown[] = [];

    const { data: fotos } = await db
      .from("fotos")
      .select("id, path_alta, cortesia, ordem, nome_original, bytes")
      .eq("banda_id", banda.id)
      .order("ordem");

    for (const f of fotos ?? []) {
      if (!liberado && !f.cortesia) continue;
      const url = await assina(f.path_alta);
      if (url) itens.push({
        tipo: "foto", id: f.id, titulo: f.nome_original ?? "Foto",
        cortesia: f.cortesia, bytes: f.bytes, url,
      });
    }

    if (liberado) {
      const { data: videos } = await db
        .from("videos")
        .select("id, titulo, duracao, path_alta, url_externa, path_previa, bytes, ordem")
        .eq("banda_id", banda.id)
        .order("ordem");

      for (const v of videos ?? []) {
        const url = await urlVideo(v);
        if (url) itens.push({
          tipo: "video", id: v.id, titulo: v.titulo,
          duracao: v.duracao, bytes: v.bytes, url,
        });
      }

      const { data: extras } = await db
        .from("downloads")
        .select("titulo, descricao, tamanho, url, ordem")
        .eq("banda_id", banda.id)
        .order("ordem");

      for (const d of extras ?? []) {
        itens.push({ tipo: "link", titulo: d.titulo, descricao: d.descricao, tamanho: d.tamanho, url: d.url });
      }
    }

    await db.rpc("registra_acesso", { p_chave: chave, p_tipo: "baixou", p_detalhe: "lista" });
    return resposta({
      banda: banda.nome,
      liberado,
      pacote: banda.pacote_comprado ?? "",
      expira_em: VALIDADE,
      itens,
    });
  }

  return resposta({ erro: "acao invalida" }, 400);
});
