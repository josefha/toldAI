import { test } from "node:test";
import assert from "node:assert/strict";
import { createClient } from "@supabase/supabase-js";
import { randomUUID } from "node:crypto";
test(
  "real email OTP verification and refresh token rotation",
  { skip: !process.env.TEST_SUPABASE_SERVICE_KEY },
  async () => {
    const url = process.env.TEST_SUPABASE_URL!;
    const admin = createClient(url, process.env.TEST_SUPABASE_SERVICE_KEY!, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const email = `told-otp-${randomUUID()}@example.com`;
    let id: string | undefined;
    try {
      const { data, error } = await admin.auth.admin.generateLink({
        type: "magiclink",
        email,
      });
      assert.ifError(error);
      id = data.user!.id;
      const response = await fetch(`${url}/auth/v1/verify`, {
        method: "POST",
        headers: {
          apikey: process.env.TEST_SUPABASE_ANON_KEY!,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          email,
          token: data.properties!.email_otp,
          type: "email",
        }),
      });
      assert.equal(response.status, 200);
      const tokens: any = await response.json();
      assert.equal(tokens.user.id, id);
      assert.ok(tokens.refresh_token);
      const refresh = await fetch(
        `${url}/auth/v1/token?grant_type=refresh_token`,
        {
          method: "POST",
          headers: {
            apikey: process.env.TEST_SUPABASE_ANON_KEY!,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ refresh_token: tokens.refresh_token }),
        },
      );
      assert.equal(refresh.status, 200);
      const renewed: any = await refresh.json();
      assert.ok(renewed.access_token);
      assert.equal(renewed.user.id, id);
    } finally {
      if (id) await admin.auth.admin.deleteUser(id);
    }
  },
);
