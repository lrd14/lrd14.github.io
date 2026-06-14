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

    if (request.method === "POST" && url.pathname === "/presence/heartbeat") {
      try {
        const body = await readJsonBody(request);
        const userId = sanitizePresenceUserId(body.userId);
        const username = sanitizePresenceUsername(body.username);
        const gameId = sanitizePresenceGameId(body.gameId);
        const launchedAtTick = sanitizePresenceTick(body.launchedAtTick);
        const playingSinceTick = sanitizePresenceTick(body.playingSinceTick);
        if (!userId) {
          return json({ success: false, message: "Missing or invalid userId." }, 400, env);
        }
        const windowSeconds = getPresenceOnlineWindowSeconds(env);
        const profile = await markUserPresence(env, {
          userId,
          username,
          gameId,
          launchedAtTick,
          playingSinceTick
        }, windowSeconds);
        return json({ success: true, onlineWindowSeconds: windowSeconds, user: profile }, 200, env);
      } catch (error) {
        const message = error instanceof Error ? error.message : "Presence heartbeat failed.";
        return json({ success: false, message }, 502, env);
      }
    }

    if (request.method === "GET" && url.pathname === "/presence/online") {
      try {
        const limit = clampPresenceLimit(url.searchParams.get("limit"));
        const users = await getOnlinePresenceUsers(env, limit);
        const userIds = users.map((entry) => entry.userId);
        const usersById = Object.fromEntries(users.map((entry) => [entry.userId, {
          username: entry.username || entry.userId,
          gameId: entry.gameId || "",
          launchedAtTick: entry.launchedAtTick || 0,
          playingSinceTick: entry.playingSinceTick || 0,
          lastSeenAt: entry.lastSeenAt || ""
        }]));
        return json({ success: true, count: users.length, userIds, users, usersById }, 200, env);
      } catch (error) {
        const message = error instanceof Error ? error.message : "Could not read online users.";
        return json({ success: false, message }, 502, env);
      }
    }

    if (request.method === "POST" && url.pathname === "/presence/remove") {
      try {
        const body = await readJsonBody(request);
        const userId = sanitizePresenceUserId(body.userId);
        if (!userId) {
          return json({ success: false, message: "Missing or invalid userId." }, 400, env);
        }
        await removeUserPresence(env, userId);
        return json({ success: true, userId }, 200, env);
      } catch (error) {
        const message = error instanceof Error ? error.message : "Could not remove userId.";
        return json({ success: false, message }, 502, env);
      }
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

    if (request.method === "GET" && url.pathname === "/catalog/public/list") {
      try {
        assertCatalogConfigured(env);
        const auth = await verifyCatalogAuth(request, env);
        const index = await getCatalogIndex(env);
        return json({ success: true, username: auth.username, items: index.slice(0, 120) }, 200, env);
      } catch (error) {
        const message = error instanceof Error ? error.message : "Catalog is unavailable.";
        const status = message === "Unauthorized." ? 401 : 500;
        return json({ success: false, message }, status, env);
      }
    }

    if (request.method === "GET" && url.pathname === "/catalog/public/item") {
      const id = String(url.searchParams.get("id") || "").trim();
      if (!id) {
        return json({ success: false, message: "Missing item id." }, 400, env);
      }
      try {
        assertCatalogConfigured(env);
        await verifyCatalogAuth(request, env);
        const item = await getCatalogItem(env, id);
        if (!item) {
          return json({ success: false, message: "Item not found." }, 404, env);
        }
        return json({ success: true, item }, 200, env);
      } catch (error) {
        const message = error instanceof Error ? error.message : "Catalog is unavailable.";
        const status = message === "Unauthorized." ? 401 : 500;
        return json({ success: false, message }, status, env);
      }
    }

    if (request.method === "GET" && url.pathname === "/catalog/public/image") {
      const id = String(url.searchParams.get("id") || "").trim();
      if (!id) {
        return new Response("Missing item id.", { status: 400 });
      }
      try {
        assertCatalogConfigured(env);
        await verifyCatalogAuth(request, env);
        const item = await getCatalogItem(env, id);
        if (!item || !item.imageKey) {
          return new Response("Image not found.", { status: 404 });
        }
        const object = await env.CATALOG_FILES.get(item.imageKey);
        if (!object) {
          return new Response("Image not found.", { status: 404 });
        }
        const headers = new Headers();
        headers.set("Content-Type", item.imageMime || object.httpMetadata?.contentType || "image/jpeg");
        headers.set("Cache-Control", "public, max-age=300");
        headers.set("X-Content-Type-Options", "nosniff");
        applyCorsHeaders(headers, env);
        return new Response(object.body, { status: 200, headers });
      } catch (error) {
        const message = error instanceof Error ? error.message : "Catalog is unavailable.";
        const status = message === "Unauthorized." ? 401 : 500;
        const headers = new Headers();
        applyCorsHeaders(headers, env);
        return new Response(message, { status, headers });
      }
    }

    if (request.method === "GET" && url.pathname === "/catalog/public/download") {
      const id = String(url.searchParams.get("id") || "").trim();
      if (!id) {
        return new Response("Missing item id.", { status: 400 });
      }
      try {
        assertCatalogConfigured(env);
        await verifyCatalogAuth(request, env);
        const item = await getCatalogItem(env, id);
        if (!item || !item.fileKey) {
          return new Response("File not found.", { status: 404 });
        }
        const object = await env.CATALOG_FILES.get(item.fileKey);
        if (!object) {
          return new Response("File not found.", { status: 404 });
        }

        await incrementCatalogDownloads(env, item.id);

        const headers = new Headers();
        headers.set("Content-Type", item.fileMime || object.httpMetadata?.contentType || "application/octet-stream");
        headers.set("Content-Disposition", `attachment; filename="${deriveCatalogDownloadName(item)}"`);
        headers.set("Cache-Control", "no-store");
        headers.set("X-Content-Type-Options", "nosniff");
        if (object.size != null) {
          headers.set("Content-Length", String(object.size));
        }
        applyCorsHeaders(headers, env);
        return new Response(object.body, { status: 200, headers });
      } catch (error) {
        const message = error instanceof Error ? error.message : "Catalog is unavailable.";
        const status = message === "Unauthorized." ? 401 : 500;
        const headers = new Headers();
        applyCorsHeaders(headers, env);
        return new Response(message, { status, headers });
      }
    }

    if (request.method === "POST" && url.pathname === "/catalog/upload") {
      try {
        assertCatalogConfigured(env);
        const auth = await verifyCatalogAuth(request, env);
        const form = await request.formData();
        const title = sanitizeCatalogText(form.get("title"), 90);
        const description = sanitizeCatalogText(form.get("description"), 1400);
        const type = String(form.get("type") || "").trim().toLowerCase();
        const author = sanitizeCatalogText(auth.username, 48) || "anonymous";
        const file = form.get("file");
        const image = form.get("image");
        const turnstileToken = String(form.get("turnstileToken") || "").trim();
        const dailyLimit = Number(env.CATALOG_DAILY_UPLOAD_LIMIT || 3);

        if (!title) {
          return json({ success: false, message: "Title is required." }, 400, env);
        }
        if (!description) {
          return json({ success: false, message: "Description is required." }, 400, env);
        }
        if (type !== "config" && type !== "lua") {
          return json({ success: false, message: "Type must be config or lua." }, 400, env);
        }
        if (!(file instanceof File) || file.size <= 0) {
          return json({ success: false, message: "A config/Lua file is required." }, 400, env);
        }
        if (!(image instanceof File) || image.size <= 0) {
          return json({ success: false, message: "An image is required." }, 400, env);
        }
        if (!turnstileToken) {
          return json({ success: false, message: "Cloudflare verification is required." }, 400, env);
        }
        await verifyTurnstileToken(turnstileToken, request, env);

        const quota = await checkDailyUploadLimit(env, author, dailyLimit);
        if (!quota.allowed) {
          return json(
            {
              success: false,
              message: `Daily upload limit reached (${dailyLimit}/day). Try again tomorrow (UTC).`
            },
            429,
            env
          );
        }

        const maxFileBytes = Number(env.CATALOG_MAX_FILE_BYTES || 1 * 1024 * 1024);
        const maxImageBytes = Number(env.CATALOG_MAX_IMAGE_BYTES || 5 * 1024 * 1024);
        if (file.size > maxFileBytes) {
          return json({ success: false, message: "File is too large." }, 400, env);
        }
        if (image.size > maxImageBytes) {
          return json({ success: false, message: "Image is too large." }, 400, env);
        }
        const normalizedFileName = String(file.name || "").trim().toLowerCase();
        if (type === "lua" && !normalizedFileName.endsWith(".lua")) {
          return json({ success: false, message: "Lua uploads must use .lua files." }, 400, env);
        }
        if (type === "config" && !normalizedFileName.endsWith(".gurp")) {
          return json({ success: false, message: "Config uploads must use .gurp files." }, 400, env);
        }
        const imageType = String(image.type || "").toLowerCase();
        if (!imageType.startsWith("image/")) {
          return json({ success: false, message: "Image must be a valid image file." }, 400, env);
        }

        const id = createCatalogId();
        const safeFileName = sanitizeFileName(file.name || `${type}.txt`);
        const safeImageName = sanitizeFileName(image.name || "preview.png");
        const preferredExt = type === "lua" ? "lua" : "gurp";
        const preferredBaseName = sanitizeFileStem(title) || `catalog_${id}`;
        const preferredDownloadName = `${preferredBaseName}.${preferredExt}`;
        const fileKey = `catalog/files/${id}/${safeFileName}`;
        const imageKey = `catalog/images/${id}/${safeImageName}`;

        await env.CATALOG_FILES.put(fileKey, file.stream(), {
          httpMetadata: { contentType: String(file.type || "application/octet-stream") }
        });
        await env.CATALOG_FILES.put(imageKey, image.stream(), {
          httpMetadata: { contentType: imageType || "image/png" }
        });

        const createdAt = new Date().toISOString();
        const item = {
          id,
          type,
          title,
          description,
          author,
          fileKey,
          fileName: preferredDownloadName,
          fileMime: String(file.type || "application/octet-stream"),
          imageKey,
          imageMime: imageType || "image/png",
          downloads: 0,
          createdAt
        };

        await saveCatalogItem(env, item);
        const index = await getCatalogIndex(env);
        index.unshift(toCatalogSummary(item));
        await saveCatalogIndex(env, index.slice(0, 600));
        await incrementDailyUploadLimit(env, quota.keyPath, quota.count + 1);

        return json({ success: true, item: toCatalogSummary(item) }, 200, env);
      } catch (error) {
        const message = error instanceof Error ? error.message : "Upload failed.";
        const status = message === "Unauthorized." ? 401 : 502;
        return json({ success: false, message }, status, env);
      }
    }

    if (
      request.method === "POST" &&
      (url.pathname === "/catalog/delete" || url.pathname === "/catalog/admin/delete")
    ) {
      try {
        assertCatalogConfigured(env);
        const auth = await verifyCatalogAuth(request, env);
        const body = await readJsonBody(request);
        const adminToken = String(body.adminToken || "").trim();
        const id = String(body.id || "").trim();
        if (!id) {
          return json({ success: false, message: "Missing item id." }, 400, env);
        }

        const item = await getCatalogItem(env, id);
        if (!item) {
          return json({ success: false, message: "Item not found." }, 404, env);
        }

        const hasAdminToken = Boolean(env.CATALOG_ADMIN_TOKEN) && adminToken === env.CATALOG_ADMIN_TOKEN;
        const isOwner = catalogUsersMatch(auth.username, item.author);
        if (!hasAdminToken && !isOwner) {
          return json({ success: false, message: "Unauthorized." }, 401, env);
        }

        const removed = await deleteCatalogItemAndAssets(env, id, item);
        if (!removed) {
          return json({ success: false, message: "Item not found." }, 404, env);
        }
        return json({ success: true, id, removedBy: auth.username }, 200, env);
      } catch (error) {
        const message = error instanceof Error ? error.message : "Delete failed.";
        const status = message === "Unauthorized." ? 401 : 502;
        return json({ success: false, message }, status, env);
      }
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
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
    "Access-Control-Expose-Headers": "Content-Disposition, Content-Type, Content-Length",
    "Access-Control-Max-Age": "86400"
  };
}

function applyCorsHeaders(headers, env) {
  const cors = corsHeaders(env);
  Object.entries(cors).forEach(([k, v]) => headers.set(k, v));
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

function assertCatalogConfigured(env) {
  if (!env.CATALOG_FILES) {
    throw new Error("Catalog storage is not configured.");
  }
}

function readBearerToken(request) {
  const header = String(request.headers.get("Authorization") || "").trim();
  if (!header.toLowerCase().startsWith("bearer ")) return "";
  return header.slice(7).trim();
}

async function verifyCatalogAuth(request, env) {
  const token = readBearerToken(request);
  if (!token) {
    throw new Error("Unauthorized.");
  }
  const payload = await verifyToken(token, env.TOKEN_SECRET);
  if (!payload || !payload.u || Number(payload.exp) < Date.now()) {
    throw new Error("Unauthorized.");
  }
  return { username: String(payload.u || "") };
}

async function getCatalogIndex(env) {
  const object = await env.CATALOG_FILES.get("catalog/index.json");
  if (!object) return [];
  try {
    const text = await object.text();
    const parsed = JSON.parse(text);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

async function saveCatalogIndex(env, index) {
  await env.CATALOG_FILES.put("catalog/index.json", JSON.stringify(index));
}

async function getCatalogItem(env, id) {
  const object = await env.CATALOG_FILES.get(`catalog/items/${id}.json`);
  if (!object) return null;
  try {
    const text = await object.text();
    const parsed = JSON.parse(text);
    return parsed && typeof parsed === "object" ? parsed : null;
  } catch {
    return null;
  }
}

async function saveCatalogItem(env, item) {
  await env.CATALOG_FILES.put(`catalog/items/${item.id}.json`, JSON.stringify(item));
}

function sanitizeCatalogText(value, maxLen) {
  const text = String(value == null ? "" : value)
    .replace(/\r/g, "")
    .trim();
  if (!text) return "";
  return text.slice(0, maxLen);
}

function sanitizeFileName(name) {
  const text = String(name || "")
    .trim()
    .replace(/[^\w.\-() ]+/g, "_")
    .replace(/\s+/g, "_")
    .slice(0, 90);
  return text || `upload_${Date.now()}`;
}

function sanitizeFileStem(name) {
  const text = String(name || "")
    .trim()
    .replace(/[^\w\-() ]+/g, "_")
    .replace(/\s+/g, "_")
    .replace(/^_+|_+$/g, "")
    .slice(0, 70);
  return text || "";
}

function createCatalogId() {
  return `${Date.now().toString(36)}${crypto.randomUUID().replace(/-/g, "").slice(0, 8)}`;
}

function toCatalogSummary(item) {
  return {
    id: item.id,
    type: item.type,
    title: item.title,
    description: item.description,
    author: item.author,
    createdAt: item.createdAt,
    downloads: Number(item.downloads || 0)
  };
}

function deriveCatalogDownloadName(item) {
  const type = String(item && item.type ? item.type : "").toLowerCase();
  const ext = type === "lua" ? "lua" : "gurp";
  const stem = sanitizeFileStem(item && item.title ? item.title : "") || sanitizeFileStem(item && item.fileName ? item.fileName : "");
  return `${stem || "download"}.${ext}`;
}

function catalogUtcDateKey() {
  const d = new Date();
  const year = d.getUTCFullYear();
  const month = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function sanitizeCatalogUserKey(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/[^\w.\-]+/g, "_")
    .slice(0, 60) || "anonymous";
}

async function checkDailyUploadLimit(env, username, limit) {
  const safeLimit = Number.isFinite(limit) && limit > 0 ? Math.floor(limit) : 3;
  const dateKey = catalogUtcDateKey();
  const userKey = sanitizeCatalogUserKey(username);
  const keyPath = `catalog/limits/${dateKey}/${userKey}.json`;
  const object = await env.CATALOG_FILES.get(keyPath);
  let count = 0;
  if (object) {
    try {
      const parsed = JSON.parse(await object.text());
      count = Number(parsed && parsed.count ? parsed.count : 0);
      if (!Number.isFinite(count) || count < 0) count = 0;
    } catch {
      count = 0;
    }
  }
  return {
    allowed: count < safeLimit,
    count,
    keyPath
  };
}

async function incrementDailyUploadLimit(env, keyPath, nextCount) {
  const safeCount = Number.isFinite(nextCount) && nextCount > 0 ? Math.floor(nextCount) : 1;
  await env.CATALOG_FILES.put(
    keyPath,
    JSON.stringify({
      count: safeCount,
      updatedAt: new Date().toISOString()
    })
  );
}

async function incrementCatalogDownloads(env, id) {
  const item = await getCatalogItem(env, id);
  if (!item) return;
  item.downloads = Number(item.downloads || 0) + 1;
  await saveCatalogItem(env, item);

  const index = await getCatalogIndex(env);
  const idx = index.findIndex((entry) => String(entry.id || "") === id);
  if (idx !== -1) {
    index[idx] = {
      ...index[idx],
      downloads: item.downloads
    };
    await saveCatalogIndex(env, index);
  }
}

async function deleteCatalogItemAndAssets(env, id, preloadedItem) {
  const item = preloadedItem || (await getCatalogItem(env, id));
  if (!item) return false;

  const deletes = [];
  if (item.fileKey) deletes.push(env.CATALOG_FILES.delete(item.fileKey));
  if (item.imageKey) deletes.push(env.CATALOG_FILES.delete(item.imageKey));
  deletes.push(env.CATALOG_FILES.delete(`catalog/items/${id}.json`));
  await Promise.all(deletes);

  const index = await getCatalogIndex(env);
  const next = index.filter((entry) => String(entry.id || "") !== id);
  await saveCatalogIndex(env, next);
  return true;
}

function catalogUsersMatch(a, b) {
  return sanitizeCatalogUserKey(a) === sanitizeCatalogUserKey(b);
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

function getPresenceStore(env) {
  if (!env.STATUS_KV) {
    throw new Error("Presence storage is not configured.");
  }
  return env.STATUS_KV;
}

function sanitizePresenceUserId(value) {
  return String(value || "")
    .trim()
    .replace(/[^\w.\-:@]+/g, "_")
    .slice(0, 80);
}

function sanitizePresenceUsername(value) {
  return String(value || "")
    .trim()
    .replace(/[^\w.\-@ ]+/g, "_")
    .slice(0, 80);
}

function sanitizePresenceGameId(value) {
  return String(value || "")
    .trim()
    .replace(/[^\w.\-:@]+/g, "_")
    .slice(0, 80);
}

function sanitizePresenceTick(value) {
  const raw = Number(value);
  if (!Number.isFinite(raw) || raw < 0) return 0;
  return Math.floor(raw);
}

function getPresenceOnlineWindowSeconds(env) {
  const raw = Number(env.PRESENCE_ONLINE_WINDOW_SECONDS || 120);
  if (!Number.isFinite(raw) || raw < 15) return 120;
  return Math.min(3600, Math.floor(raw));
}

function clampPresenceLimit(value) {
  const raw = Number(value || 200);
  if (!Number.isFinite(raw) || raw <= 0) return 200;
  return Math.min(500, Math.floor(raw));
}

function presenceIndexKey() {
  return "presence:index:v1";
}

async function getPresenceIndex(env) {
  const kv = getPresenceStore(env);
  const raw = await kv.get(presenceIndexKey());
  if (!raw) return {};
  try {
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch {
    return {};
  }
}

async function savePresenceIndex(env, index) {
  const kv = getPresenceStore(env);
  await kv.put(presenceIndexKey(), JSON.stringify(index), {
    expirationTtl: 7 * 24 * 60 * 60
  });
}

function prunePresenceIndex(index, nowMs) {
  const safeNow = Number.isFinite(nowMs) ? nowMs : Date.now();
  const entries = Object.entries(index || {});
  const pruned = {};
  for (const [userId, value] of entries) {
    const safe = sanitizePresenceRecord(value);
    if (!safe || safe.expiresAt <= safeNow) continue;
    pruned[userId] = safe;
  }
  return pruned;
}

function sanitizePresenceRecord(value) {
  const parsed = value && typeof value === "object" ? value : {};
  const userId = sanitizePresenceUserId(parsed.userId);
  if (!userId) return null;
  const username = sanitizePresenceUsername(parsed.username);
  const gameId = sanitizePresenceGameId(parsed.gameId);
  const launchedAtTick = sanitizePresenceTick(parsed.launchedAtTick);
  const playingSinceTick = sanitizePresenceTick(parsed.playingSinceTick);
  const lastSeenAt = String(parsed.lastSeenAt || "");
  const expiresAt = Number(parsed.expiresAt || 0);
  return {
    userId,
    username: username || userId,
    gameId,
    launchedAtTick,
    playingSinceTick,
    lastSeenAt,
    expiresAt
  };
}

async function markUserPresence(env, presence, windowSeconds) {
  const safePresence = sanitizePresenceRecord(presence);
  if (!safePresence) {
    throw new Error("Missing or invalid userId.");
  }
  const now = Date.now();
  const expiresAt = now + windowSeconds * 1000;
  const index = prunePresenceIndex(await getPresenceIndex(env), now);
  const prior = sanitizePresenceRecord(index[safePresence.userId]);

  const payload = {
    userId: safePresence.userId,
    username: safePresence.username || (prior ? prior.username : safePresence.userId),
    gameId: safePresence.gameId || (prior ? prior.gameId : ""),
    launchedAtTick: safePresence.launchedAtTick > 0 ? safePresence.launchedAtTick : (prior ? prior.launchedAtTick : 0),
    playingSinceTick: safePresence.playingSinceTick > 0 ? safePresence.playingSinceTick : (prior ? prior.playingSinceTick : 0),
    lastSeenAt: new Date(now).toISOString(),
    expiresAt
  };
  index[safePresence.userId] = payload;
  await savePresenceIndex(env, index);
  return payload;
}

async function removeUserPresence(env, userId) {
  const index = await getPresenceIndex(env);
  if (index && Object.prototype.hasOwnProperty.call(index, userId)) {
    delete index[userId];
    await savePresenceIndex(env, index);
  }
}

async function getOnlinePresenceUsers(env, limit) {
  const now = Date.now();
  const index = await getPresenceIndex(env);
  const cleaned = prunePresenceIndex(index, now);
  if (JSON.stringify(cleaned) !== JSON.stringify(index)) {
    await savePresenceIndex(env, cleaned);
  }

  const sorted = Object.values(cleaned)
    .map((value) => sanitizePresenceRecord(value))
    .filter(Boolean)
    .sort((a, b) => Number(b.expiresAt || 0) - Number(a.expiresAt || 0))
    .slice(0, limit);

  return sorted.map((parsed) => ({
    userId: parsed.userId,
    username: parsed.username || parsed.userId,
    gameId: parsed.gameId || "",
    launchedAtTick: parsed.launchedAtTick || 0,
    playingSinceTick: parsed.playingSinceTick || 0,
    lastSeenAt: parsed.lastSeenAt || ""
  }));
}
