// ============================================================
//  entrega — portal privado de fotos e videos por aluno/familia
//
//  GET ?chave=<slug-token>&acao=dados      -> pagina + midias
//  GET ?chave=<slug-token>&acao=downloads  -> links de download
//  GET ?chave=<slug-token>&acao=item&id=    -> um download
// ============================================================
import { createClient } from "npm:@supabase/supabase-js@2.112.3";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SIGNED_URL_SECONDS = 60 * 60;
const db = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-retry-count, traceparent, tracestate, baggage",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

const response = (body: unknown, status = 200) =>
  Response.json(body, {
    status,
    headers: { ...CORS, "Cache-Control": "private, no-store" },
  });

const KEY_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)+$/;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

async function signed(path: string | null, download: boolean | string = false) {
  if (!path) return null;
  const { data, error } = await db.storage
    .from("entregas")
    .createSignedUrl(path, SIGNED_URL_SECONDS, download ? { download } : undefined);
  return error ? null : data.signedUrl;
}

async function logAccess(deliveryId: string | null, key: string, type: string, detail = "") {
  await db.from("entrega_acessos").insert({
    entrega_id: deliveryId,
    chave: key.slice(0, 120),
    tipo: type,
    detalhe: detail.slice(0, 240),
  });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (request.method !== "GET") return response({ erro: "metodo" }, 405);

  const url = new URL(request.url);
  const key = (url.searchParams.get("chave") ?? "").trim().toLowerCase();
  const action = url.searchParams.get("acao") ?? "dados";

  if (!KEY_PATTERN.test(key) || key.length < 12 || key.length > 160) {
    return response({ erro: "link_invalido" }, 404);
  }

  const { data: delivery } = await db
    .from("entregas")
    .select(`
      id, titulo, chave, unidade, estado, liberado, validade, atualizado_em,
      eventos!inner(id, nome, slug, descricao, data_evento, local, whatsapp),
      entrega_participantes(id, nome, unidade, foto_url, ordem),
      entrega_midias(id, tipo, titulo, path_original, path_previa, poster_path,
        mime_type, bytes, largura, altura, duracao, ordem)
    `)
    .eq("chave", key)
    .in("estado", ["publicada", "liberada"])
    .maybeSingle();

  if (!delivery) {
    return response({ erro: "link_invalido" }, 404);
  }

  if (delivery.validade && new Date(`${delivery.validade}T23:59:59-03:00`) < new Date()) {
    return response({ erro: "link_vencido" }, 410);
  }

  const participants = [...(delivery.entrega_participantes ?? [])]
    .sort((a, b) => a.ordem - b.ordem)
    .map(({ id, nome, unidade, foto_url }) => ({ id, nome, unidade, fotoUrl: foto_url }));
  const event = Array.isArray(delivery.eventos) ? delivery.eventos[0] : delivery.eventos;

  if (action === "dados") {
    const media = [];
    if (delivery.liberado) {
      for (const item of [...(delivery.entrega_midias ?? [])].sort((a, b) => a.ordem - b.ordem)) {
        const previewPath = item.path_previa || item.path_original;
        const previewUrl = item.tipo === "arquivo" ? null : await signed(previewPath);
        const posterUrl = item.poster_path ? await signed(item.poster_path) : null;
        media.push({
          id: item.id,
          tipo: item.tipo,
          titulo: item.titulo,
          mimeType: item.mime_type,
          bytes: item.bytes,
          largura: item.largura,
          altura: item.altura,
          duracao: item.duracao,
          previewUrl,
          posterUrl,
        });
      }
    }

    await logAccess(delivery.id, key, "abriu");
    return response({
      entrega: {
        id: delivery.id,
        titulo: delivery.titulo,
        unidade: delivery.unidade,
        liberado: delivery.liberado,
        atualizadoEm: delivery.atualizado_em,
      },
      evento: event,
      participantes: participants,
      midias: media,
      linksExpiramEm: SIGNED_URL_SECONDS,
    });
  }

  if (!delivery.liberado) return response({ erro: "ainda_nao_liberado" }, 403);

  if (action === "downloads") {
    const items = [];
    for (const item of [...(delivery.entrega_midias ?? [])].sort((a, b) => a.ordem - b.ordem)) {
      const url = await signed(item.path_original, item.titulo || true);
      if (url) items.push({
        id: item.id,
        tipo: item.tipo,
        titulo: item.titulo,
        mimeType: item.mime_type,
        bytes: item.bytes,
        url,
      });
    }
    await logAccess(delivery.id, key, "baixou", "lista");
    return response({ itens: items, expiraEm: SIGNED_URL_SECONDS });
  }

  if (action === "item") {
    const id = url.searchParams.get("id") ?? "";
    if (!UUID_PATTERN.test(id)) return response({ erro: "item_invalido" }, 400);
    const item = (delivery.entrega_midias ?? []).find((candidate) => candidate.id === id);
    if (!item) return response({ erro: "item_invalido" }, 404);
    const signedUrl = await signed(item.path_original, item.titulo || true);
    if (!signedUrl) return response({ erro: "arquivo_indisponivel" }, 404);
    await logAccess(delivery.id, key, "baixou", `${item.tipo} ${item.id}`);
    return response({ url: signedUrl, expiraEm: SIGNED_URL_SECONDS });
  }

  return response({ erro: "acao_invalida" }, 400);
});
