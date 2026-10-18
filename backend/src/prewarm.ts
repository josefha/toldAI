import { createHash } from "node:crypto";
import { readConfig } from "./config.js";
import { Store, check } from "./store.js";
const store = new Store(readConfig());
// Daily scheduled submission; the regular worker shares content by interest cohort.
let offset = 0;
let count = 0;
while (true) {
  const { data, error } = await store.db
    .from("profiles")
    .select("user_id,data")
    .order("user_id")
    .range(offset, offset + 199);
  check(error);
  if (!data?.length) break;
  for (const row of data) {
    if (!row.data.completedOnboarding) continue;
    const hash = createHash("sha256")
      .update(`daily:${new Date().toISOString().slice(0, 10)}:${row.user_id}`)
      .digest("hex");
    const id = `${hash.slice(0, 8)}-${hash.slice(8, 12)}-4${hash.slice(13, 16)}-a${hash.slice(17, 20)}-${hash.slice(20, 32)}`;
    const { error } = await store.db
      .from("jobs")
      .upsert(
        {
          id,
          user_id: row.user_id,
          kind: "daily",
          input: { kind: "daily", requestID: id },
        },
        { onConflict: "id", ignoreDuplicates: true },
      );
    check(error);
    count++;
  }
  offset += data.length;
}
console.log(`Queued daily preparation for ${count} accounts.`);
