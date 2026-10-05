// ============================================================
//  entregas-admin — operacoes privadas da Mesa de Entregas
//
//  POST { acao: "sincronizar_crm", eventoId: "..." }
//  Consulta somente contratados no CRM e cria/atualiza entregas.
// ============================================================
import { createClient } from "npm:@supabase/supabase-js@2.112.3";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const CRM_API_URL = Deno.env.get("CRM_API_URL")!;
const CRM_SITES_BYPASS_TOKEN = Deno.env.get("CRM_SITES_BYPASS_TOKEN")!;
const CRM_SYNC_SECRET = Deno.env.get("CRM_SYNC_SECRET")!;
const db = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-camarim-sync, x-retry-count, traceparent, tracestate, baggage",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const response = (body: unknown, status = 200) =>
  Response.json(body, { status, headers: { ...CORS, "Cache-Control": "private, no-store" } });
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function slugify(value: string) {
  return value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase()
    .replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 70) || "participante";
}

function text(value: unknown, max = 160) {
  return typeof value === "string" ? value.trim().slice(0, max) : "";
}

async function requireAdmin(request: Request) {
  const authorization = request.headers.get("Authorization") ?? "";
  const token = authorization.replace(/^Bearer\s+/i, "");
  if (!token) return null;
  // Permite tarefas internas do proprio backend, sem expor essa chave no navegador.
  if (token === SERVICE_ROLE || request.headers.get("x-camarim-sync") === CRM_SYNC_SECRET) {
    return { id: "service-role" };
  }
  const { data: { user } } = await db.auth.getUser(token);
  if (!user) return null;
  const { data: admin } = await db.from("admins").select("user_id").eq("user_id", user.id).maybeSingle();
  return admin ? user : null;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (request.method !== "POST") return response({ erro: "metodo" }, 405);
  if (!await requireAdmin(request)) return response({ erro: "nao_autorizado" }, 401);

  let body: { acao?: string; eventoId?: string };
  try {
    const raw = await request.text();
    if (raw.length > 8000) return response({ erro: "pedido_muito_grande" }, 413);
    body = JSON.parse(raw);
  } catch {
    return response({ erro: "pedido_invalido" }, 400);
  }

  if (body.acao !== "sincronizar_crm" || !body.eventoId || !UUID_PATTERN.test(body.eventoId)) {
    return response({ erro: "acao_invalida" }, 400);
  }
  if (!CRM_API_URL || !CRM_SITES_BYPASS_TOKEN || !CRM_SYNC_SECRET) {
    return response({ erro: "integracao_nao_configurada" }, 503);
  }

  const { data: event } = await db.from("eventos").select("id, integracao").eq("id", body.eventoId).maybeSingle();
  if (!event) return response({ erro: "evento_invalido" }, 404);
  if (event.integracao !== "vocal_kids_crm") return response({ erro: "evento_sem_integracao" }, 409);

  const crmResponse = await fetch(CRM_API_URL, {
    headers: {
      "OAI-Sites-Authorization": `Bearer ${CRM_SITES_BYPASS_TOKEN}`,
      "x-camarim-sync": CRM_SYNC_SECRET,
      "Accept": "application/json",
    },
  });
  if (!crmResponse.ok) {
    console.error("CRM sync failed", crmResponse.status);
    return response({ erro: "crm_indisponivel" }, 502);
  }

  const payload = await crmResponse.json();
  const students = Array.isArray(payload?.students) ? payload.students.slice(0, 500) : [];
  let created = 0;
  let updated = 0;
  let paid = 0;

  for (const source of students) {
    const crmId = text(source?.id, 100);
    const name = text(source?.name);
    if (!crmId || !name || source?.contract !== "yes") continue;
    const payment = source?.payment === "paid" ? "paid" : source?.payment === "pending" ? "pending" : "unknown";
    if (payment === "paid") paid += 1;
    const common = {
      titulo: name,
      responsavel_nome: text(source?.guardian),
      responsavel_telefone: text(source?.phone, 40),
      unidade: text(source?.unit, 80),
      contrato: "yes",
      pagamento: payment,
      origem: "crm",
      origem_atualizada_em: new Date().toISOString(),
    };

    const { data: existing } = await db.from("entregas")
      .select("id").eq("evento_id", event.id).eq("crm_id", crmId).maybeSingle();

    let deliveryId: string;
    if (existing) {
      const { error } = await db.from("entregas").update(common).eq("id", existing.id);
      if (error) throw error;
      deliveryId = existing.id;
      updated += 1;
    } else {
      const suffix = slugify(crmId).slice(-10);
      const { data: inserted, error } = await db.from("entregas").insert({
        ...common,
        evento_id: event.id,
        crm_id: crmId,
        slug: `${slugify(name)}-${suffix}`.replace(/-+$/g, ""),
      }).select("id").single();
      if (error) throw error;
      deliveryId = inserted.id;
      created += 1;
    }

    const participant = {
      nome: name,
      unidade: text(source?.unit, 80),
      foto_url: text(source?.photoUrl, 800),
    };
    const { data: existingParticipant } = await db.from("entrega_participantes")
      .select("id").eq("entrega_id", deliveryId).eq("crm_id", crmId).maybeSingle();
    if (existingParticipant) {
      const { error } = await db.from("entrega_participantes").update(participant).eq("id", existingParticipant.id);
      if (error) throw error;
    } else {
      const { error } = await db.from("entrega_participantes").insert({
        ...participant, entrega_id: deliveryId, crm_id: crmId, ordem: 0,
      });
      if (error) throw error;
    }
  }

  return response({ total: created + updated, criados: created, atualizados: updated, pagos: paid });
});
