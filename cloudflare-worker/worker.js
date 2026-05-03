export default {
  async fetch(request, env) {
    const url = new URL(request.url);

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

        const token = await signToken(
          {
            u: username,
            exp: Date.now() + 1000 * 60 * 60 * 8
          },
          env.TOKEN_SECRET
        );

        return json(
          {
            success: true,
            username,
            token,
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

        const token = await signToken(
          {
            u: username,
            exp: Date.now() + 1000 * 60 * 60 * 8
          },
          env.TOKEN_SECRET
        );

        return json(
          {
            success: true,
            username,
            token,
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
