export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "POST" && url.pathname === "/stripe/webhook") {
      const payload = await request.text();
      const signature = request.headers.get("Stripe-Signature") || "";
      const valid = await verifyStripeSignature(payload, signature, env.STRIPE_WEBHOOK_SECRET || "");
      if (!valid) {
        return new Response("Invalid signature.", { status: 400 });
      }

      let event = null;
      try {
        event = JSON.parse(payload);
      } catch {
        return new Response("Invalid payload.", { status: 400 });
      }

      if (event && event.type === "checkout.session.completed") {
        const session = event.data && event.data.object ? event.data.object : {};
        await sendPurchaseWebhook(session, env);
      }

      return new Response("ok", { status: 200 });
    }

    if (request.method === "POST" && url.pathname === "/payments/create-checkout") {
      const body = await readJsonBody(request);
      const discordUsername = String(body.discordUsername || "").trim();
      const agreedTos = Boolean(body.agreedTos);

      if (!discordUsername) {
        return json({ success: false, message: "Discord username is required." }, 400, env);
      }
      if (discordUsername.length > 64) {
        return json({ success: false, message: "Discord username is too long." }, 400, env);
      }
      if (!agreedTos) {
        return json({ success: false, message: "You must agree to the terms of service." }, 400, env);
      }
      if (!env.STRIPE_SECRET_KEY || !env.STRIPE_PRICE_ID || !env.STRIPE_SUCCESS_URL || !env.STRIPE_CANCEL_URL) {
        return json({ success: false, message: "Stripe is not fully configured." }, 500, env);
      }

      try {
        const checkout = await createStripeCheckoutSession({
          stripeSecret: env.STRIPE_SECRET_KEY,
          priceId: env.STRIPE_PRICE_ID,
          successUrl: env.STRIPE_SUCCESS_URL,
          cancelUrl: env.STRIPE_CANCEL_URL,
          discordUsername
        });

        return json(
          {
            success: true,
            checkoutUrl: checkout.url
          },
          200,
          env
        );
      } catch (error) {
        const message = error instanceof Error ? error.message : "Unable to create checkout session.";
        return json({ success: false, message }, 502, env);
      }
    }

    if (request.method === "GET" && url.pathname === "/status/public") {
      const state = await getStatusState(env);
      const history = await getStatusHistory(env);
      return json(
        {
          success: true,
          ...state,
          history
        },
        200,
        env
      );
    }

    if (request.method === "POST" && url.pathname === "/status/admin/update") {
      const body = await readJsonBody(request);
      const adminToken = String(body.adminToken || "").trim();
      if (!adminToken || !env.STATUS_ADMIN_TOKEN || adminToken !== env.STATUS_ADMIN_TOKEN) {
        return json({ success: false, message: "Unauthorized." }, 401, env);
      }

      const incomingServices = Array.isArray(body.services) ? body.services : [];
      const rawServices = incomingServices
        .map((svc) => ({
          name: String(svc.name || "").trim(),
          status: normalizeStatus(String(svc.status || "ok")),
          detail: String(svc.detail || "").trim()
        }))
        .filter((svc) => svc.name.length > 0);

      const services = enforceServiceTemplate(rawServices);

      const overall = normalizeStatus(String(body.overall || ""));
      const message = String(body.message || "").trim();
      const incidentNote = String(body.incidentNote || "").trim();
      const now = new Date().toISOString().replace("T", " ").replace(".000Z", " UTC");

      const currentState = await getStatusState(env);
      const nextState = {
        updatedAt: now,
        overall: overall || deriveOverall(services),
        message: message || "Status updated.",
        services,
        incidents: buildIncidentList(currentState.incidents, incidentNote)
      };

      await saveStatusState(env, nextState);
      await appendStatusHistory(env, {
        ts: now,
        overall: nextState.overall,
        message: nextState.message,
        services: services.map((svc) => ({ name: svc.name, status: svc.status }))
      });

      return json({ success: true, ...nextState }, 200, env);
    }

    if (request.method === "GET" && url.pathname === "/dl") {
      const ticket = url.searchParams.get("ticket") || "";
      if (!ticket) {
        return new Response("Missing download ticket.", { status: 400 });
      }

      const payload = await verifyToken(ticket, env.TOKEN_SECRET);
      if (!payload || payload.t !== "dl" || !payload.u || Number(payload.exp) < Date.now()) {
        return new Response("Invalid or expired download ticket.", { status: 401 });
      }

      if (!env.DOWNLOADS || !env.DOWNLOAD_OBJECT_KEY) {
        return new Response("Download storage is not configured.", { status: 500 });
      }

      const object = await env.DOWNLOADS.get(env.DOWNLOAD_OBJECT_KEY);
      if (!object) {
        return new Response("Requested file not found.", { status: 404 });
      }

      const filename = env.DOWNLOAD_FILENAME || env.DOWNLOAD_OBJECT_KEY.split("/").pop() || "download.bin";
      const headers = new Headers();
      headers.set("Content-Type", object.httpMetadata?.contentType || "application/octet-stream");
      headers.set("Content-Disposition", `attachment; filename="${filename}"`);
      headers.set("Cache-Control", "no-store");
      headers.set("X-Content-Type-Options", "nosniff");
      if (object.size != null) {
        headers.set("Content-Length", String(object.size));
      }
      if (object.etag) {
        headers.set("ETag", object.etag);
      }

      return new Response(object.body, { status: 200, headers });
    }

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders(env) });
    }

    if (request.method !== "POST") {
      return json({ success: false, message: "Method not allowed." }, 405, env);
    }

    let body = {};
    try {
      body = await request.json();
    } catch {
      return json({ success: false, message: "Invalid JSON body." }, 400, env);
    }

    const action = String(body.action || "");
    if (!action) {
      return json({ success: false, message: "Missing action." }, 400, env);
    }

    try {
      if (action === "login") {
        const username = String(body.username || "").trim();
        const password = String(body.password || "");
        const turnstileToken = String(body.turnstileToken || "").trim();
        const remember = Boolean(body.remember);
        if (!username || !password) {
          return json({ success: false, message: "Username and password are required." }, 400, env);
        }
        if (!turnstileToken) {
          return json({ success: false, message: "Verification is required." }, 400, env);
        }
        await verifyTurnstileToken(turnstileToken, request, env);

        const sessionid = await keyauthInit(env);
        const result = await keyauthCall(
          {
            type: "login",
            username,
            pass: password,
            sessionid,
            name: env.KEYAUTH_NAME,
            ownerid: env.KEYAUTH_OWNER_ID
          },
          env
        );

        if (!result.success) {
          return json({ success: false, message: result.message || "Login failed." }, 401, env);
        }

        const expiresAt = Date.now() + getSessionTtlMs(remember, env);
        const token = await signToken(
          {
            u: username,
            exp: expiresAt
          },
          env.TOKEN_SECRET
        );

        return json(
          {
            success: true,
            username,
            token,
            expiresAt,
            remember,
            downloadUrl: "/download"
          },
          200,
          env
        );
      }

      if (action === "register") {
        const username = String(body.username || "").trim();
        const password = String(body.password || "");
        const license = String(body.license || "").trim();
        const turnstileToken = String(body.turnstileToken || "").trim();
        const remember = Boolean(body.remember);
        if (!username || !password || !license) {
          return json({ success: false, message: "Username, password, and license are required." }, 400, env);
        }
        if (!turnstileToken) {
          return json({ success: false, message: "Verification is required." }, 400, env);
        }
        await verifyTurnstileToken(turnstileToken, request, env);

        const sessionid = await keyauthInit(env);
        const result = await keyauthCall(
          {
            type: "register",
            username,
            pass: password,
            key: license,
            sessionid,
            name: env.KEYAUTH_NAME,
            ownerid: env.KEYAUTH_OWNER_ID
          },
          env
        );

        if (!result.success) {
          return json({ success: false, message: result.message || "Register failed." }, 401, env);
        }

        const expiresAt = Date.now() + getSessionTtlMs(remember, env);
        const token = await signToken(
          {
            u: username,
            exp: expiresAt
          },
          env.TOKEN_SECRET
        );

        return json(
          {
            success: true,
            username,
            token,
            expiresAt,
            remember,
            downloadUrl: "/download"
          },
          200,
          env
        );
      }

      if (action === "validate") {
        const token = String(body.token || "").trim();
        if (!token) {
          return json({ success: false, message: "Missing token." }, 400, env);
        }

        const payload = await verifyToken(token, env.TOKEN_SECRET);
        if (!payload || !payload.u || Number(payload.exp) < Date.now()) {
          return json({ success: false, message: "Invalid or expired token." }, 401, env);
        }

        return json(
          {
            success: true,
            username: payload.u,
            downloadUrl: await buildDownloadGatewayUrl(url, payload.u, env.TOKEN_SECRET)
          },
          200,
          env
        );
      }

      return json({ success: false, message: "Invalid action." }, 400, env);
    } catch (error) {
      const message = error instanceof Error ? error.message : "Unexpected worker error.";
      return json({ success: false, message }, 502, env);
    }
  }
};

async function keyauthInit(env) {
  const result = await keyauthCall(
    {
      type: "init",
      ver: env.KEYAUTH_VERSION,
      name: env.KEYAUTH_NAME,
      ownerid: env.KEYAUTH_OWNER_ID
    },
    env
  );

  if (!result.success || !result.sessionid) {
    throw new Error(result.message || "KeyAuth init failed.");
  }
  return result.sessionid;
}

async function keyauthCall(params, env) {
  const query = new URLSearchParams(params);
  const response = await fetch(`https://keyauth.win/api/1.3/?${query.toString()}`, {
    method: "GET",
    headers: { "User-Agent": "gurp-worker-gateway" }
  });

  const text = await response.text();
  let parsed = null;
  try {
    parsed = JSON.parse(text);
  } catch {
    throw new Error(`KeyAuth invalid response (${response.status}).`);
  }

  if (!response.ok) {
    throw new Error(parsed.message || `KeyAuth HTTP ${response.status}.`);
  }

  return parsed;
}

async function createStripeCheckoutSession({
  stripeSecret,
  priceId,
  successUrl,
  cancelUrl,
  discordUsername
}) {
  const form = new URLSearchParams();
  form.set("mode", "payment");
  form.set("success_url", successUrl);
  form.set("cancel_url", cancelUrl);
  form.set("line_items[0][price]", priceId);
  form.set("line_items[0][quantity]", "1");
  form.set("metadata[discord_username]", discordUsername);
  form.set("metadata[source]", "gurp.cc");
  form.set("payment_intent_data[metadata][discord_username]", discordUsername);
  form.set("payment_intent_data[metadata][source]", "gurp.cc");

  const response = await fetch("https://api.stripe.com/v1/checkout/sessions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${stripeSecret}`,
      "Content-Type": "application/x-www-form-urlencoded"
    },
    body: form.toString()
  });

  const data = await response.json().catch(() => ({}));
  if (!response.ok || !data || !data.url) {
    const reason = data && data.error && data.error.message ? data.error.message : "Stripe request failed.";
    throw new Error(reason);
  }

  return data;
}

async function verifyStripeSignature(payload, signatureHeader, webhookSecret) {
  if (!signatureHeader || !webhookSecret) return false;
  const parsed = parseStripeSignature(signatureHeader);
  if (!parsed.timestamp || !parsed.signature) return false;

  const signedPayload = `${parsed.timestamp}.${payload}`;
  const expected = await hmacSha256Hex(webhookSecret, signedPayload);
  if (!timingSafeEqualHex(expected, parsed.signature)) return false;

  const tsMs = Number(parsed.timestamp) * 1000;
  if (!Number.isFinite(tsMs)) return false;
  const ageMs = Math.abs(Date.now() - tsMs);
  return ageMs <= 5 * 60 * 1000;
}

function parseStripeSignature(header) {
  const parts = String(header || "")
    .split(",")
    .map((p) => p.trim());
  let timestamp = "";
  let signature = "";
  for (const part of parts) {
    const [k, v] = part.split("=");
    if (k === "t") timestamp = v || "";
    if (k === "v1" && !signature) signature = v || "";
  }
  return { timestamp, signature };
}

async function hmacSha256Hex(secret, message) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  const bytes = new Uint8Array(signature);
  let hex = "";
  for (const b of bytes) {
    hex += b.toString(16).padStart(2, "0");
  }
  return hex;
}

function timingSafeEqualHex(a, b) {
  const aa = String(a || "").toLowerCase();
  const bb = String(b || "").toLowerCase();
  if (aa.length !== bb.length) return false;
  let result = 0;
  for (let i = 0; i < aa.length; i += 1) {
    result |= aa.charCodeAt(i) ^ bb.charCodeAt(i);
  }
  return result === 0;
}

async function sendPurchaseWebhook(session, env) {
  if (!env.DISCORD_PURCHASE_WEBHOOK) return;

  const discordUsername =
    (session.metadata && session.metadata.discord_username) ||
    (session.customer_details && session.customer_details.name) ||
    "unknown";
  const amount = Number(session.amount_total || 0) / 100;
  const currency = String(session.currency || "gbp").toUpperCase();
  const sessionId = String(session.id || "unknown");

  const body = {
    embeds: [
      {
        title: "Successful Purchase",
        color: 9948765,
        description: "A new purchase completed successfully.",
        fields: [
          { name: "Discord Username", value: String(discordUsername), inline: true },
          { name: "Amount", value: `${amount.toFixed(2)} ${currency}`, inline: true },
          { name: "Session ID", value: sessionId, inline: false }
        ],
        timestamp: new Date().toISOString()
      }
    ]
  };

  await fetch(env.DISCORD_PURCHASE_WEBHOOK, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body)
  });
}

async function readJsonBody(request) {
  try {
    return await request.json();
  } catch {
    return {};
  }
}

async function verifyTurnstileToken(token, request, env) {
  if (!env.TURNSTILE_SECRET) {
    throw new Error("Turnstile secret is not configured.");
  }

  const remoteIp = request.headers.get("CF-Connecting-IP") || "";
  const formData = new URLSearchParams();
  formData.set("secret", env.TURNSTILE_SECRET);
  formData.set("response", token);
  if (remoteIp) {
    formData.set("remoteip", remoteIp);
  }

  const response = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: formData.toString()
  });

  if (!response.ok) {
    throw new Error("Verification service unavailable.");
  }

  const data = await response.json();
  if (!data.success) {
    throw new Error("Verification check failed.");
  }
}

function corsHeaders(env) {
  const origin = env.ALLOWED_ORIGIN || "*";
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "POST, OPTIONS, GET",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Max-Age": "86400"
  };
}

function json(payload, status, env) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      ...corsHeaders(env)
    }
  });
}

function toBase64Url(buffer) {
  const bytes = new Uint8Array(buffer);
  let binary = "";
  for (let i = 0; i < bytes.byteLength; i += 1) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function fromBase64Url(value) {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const pad = normalized.length % 4;
  const padded = pad ? normalized + "=".repeat(4 - pad) : normalized;
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

async function signToken(payload, secret) {
  const payloadText = JSON.stringify(payload);
  const payloadEncoded = toBase64Url(new TextEncoder().encode(payloadText));
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payloadEncoded));
  const signatureEncoded = toBase64Url(signature);
  return `${payloadEncoded}.${signatureEncoded}`;
}

async function verifyToken(token, secret) {
  const parts = token.split(".");
  if (parts.length !== 2) {
    return null;
  }

  const [payloadEncoded, signatureEncoded] = parts;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"]
  );
  const valid = await crypto.subtle.verify(
    "HMAC",
    key,
    fromBase64Url(signatureEncoded),
    new TextEncoder().encode(payloadEncoded)
  );
  if (!valid) {
    return null;
  }

  try {
    const payload = new TextDecoder().decode(fromBase64Url(payloadEncoded));
    return JSON.parse(payload);
  } catch {
    return null;
  }
}

async function buildDownloadGatewayUrl(url, username, secret) {
  const ticket = await signToken(
    {
      t: "dl",
      u: username,
      exp: Date.now() + 1000 * 60 * 10
    },
    secret
  );
  return `${url.origin}/dl?ticket=${encodeURIComponent(ticket)}`;
}

function normalizeStatus(value) {
  if (value === "down") return "down";
  if (value === "degraded") return "degraded";
  if (value === "ok") return "ok";
  return "";
}

function deriveOverall(services) {
  if (services.some((s) => s.status === "down")) return "down";
  if (services.some((s) => s.status === "degraded")) return "degraded";
  return "ok";
}

function buildIncidentList(existing, note) {
  const incidents = Array.isArray(existing) ? [...existing] : [];
  if (note) {
    incidents.unshift(note);
  }
  const deduped = [];
  for (const entry of incidents) {
    const text = String(entry || "").trim();
    if (!text) continue;
    if (!deduped.includes(text)) deduped.push(text);
    if (deduped.length >= 30) break;
  }
  return deduped.length ? deduped : ["No active incidents."];
}

async function getStatusState(env) {
  const fallback = {
    updatedAt: "Not updated yet",
    overall: "ok",
    message: "All core services are running normally.",
    services: enforceServiceTemplate([]),
    incidents: ["No active incidents."]
  };

  if (!env.STATUS_KV) {
    return fallback;
  }
  const raw = await env.STATUS_KV.get("status:current");
  if (!raw) return fallback;
  try {
    const parsed = JSON.parse(raw);
    const merged = { ...fallback, ...parsed };
    merged.services = enforceServiceTemplate(Array.isArray(parsed.services) ? parsed.services : []);
    merged.overall = deriveOverall(merged.services);
    return merged;
  } catch {
    return fallback;
  }
}

async function saveStatusState(env, state) {
  if (!env.STATUS_KV) return;
  await env.STATUS_KV.put("status:current", JSON.stringify(state));
}

async function getStatusHistory(env) {
  if (!env.STATUS_KV) return [];
  const raw = await env.STATUS_KV.get("status:history");
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

async function appendStatusHistory(env, event) {
  if (!env.STATUS_KV) return;
  const existing = await getStatusHistory(env);
  const next = [event, ...existing].slice(0, 120);
  await env.STATUS_KV.put("status:history", JSON.stringify(next));
}

function getSessionTtlMs(remember, env) {
  const daysRaw = Number(env.SESSION_TTL_DAYS || 30);
  const days = Number.isFinite(daysRaw) && daysRaw > 0 ? daysRaw : 30;
  if (remember) {
    return days * 24 * 60 * 60 * 1000;
  }
  return 8 * 60 * 60 * 1000;
}

function enforceServiceTemplate(incoming) {
  const expected = [
    { name: "Website", detail: "Main website is online." },
    { name: "API", detail: "Authentication API is responding normally." },
    { name: "Loader", detail: "Authenticated loader delivery is available." }
  ];

  const normalized = Array.isArray(incoming)
    ? incoming.map((s) => ({
        name: String(s.name || "").trim(),
        status: normalizeStatus(String(s.status || "ok")) || "ok",
        detail: String(s.detail || "").trim()
      }))
    : [];

  return expected.map((svc) => {
    const match = normalized.find((item) => item.name.toLowerCase() === svc.name.toLowerCase());
    return {
      name: svc.name,
      status: match ? match.status : "ok",
      detail: match && match.detail ? match.detail : svc.detail
    };
  });
}
