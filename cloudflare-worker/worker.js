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

      return Response.redirect(env.DOWNLOAD_URL, 302);
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
        if (!username || !password) {
          return json({ success: false, message: "Username and password are required." }, 400, env);
        }

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
            downloadUrl: "download.html"
          },
          200,
          env
        );
      }

      if (action === "register") {
        const username = String(body.username || "").trim();
        const password = String(body.password || "");
        const license = String(body.license || "").trim();
        if (!username || !password || !license) {
          return json({ success: false, message: "Username, password, and license are required." }, 400, env);
        }

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
            downloadUrl: "download.html"
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
