/**
 * One-off script: Set club default_language to English
 * and update supported_languages order.
 * 
 * Usage: node scripts/set-club-english.mjs
 */
import { createClient } from "@supabase/supabase-js";
import { readFileSync } from "node:fs";

// Read env from .env.local
const envContent = readFileSync(".env.local", "utf8");
function getEnv(key) {
  const match = envContent.match(new RegExp(`^${key}=(.+)$`, "m"));
  return match?.[1]?.trim() ?? process.env[key] ?? "";
}

const supabaseUrl = getEnv("SUPABASE_URL") || getEnv("NEXT_PUBLIC_SUPABASE_URL");
const serviceRoleKey = getEnv("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl || !serviceRoleKey) {
  console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  process.exit(1);
}

const supabase = createClient(supabaseUrl, serviceRoleKey);

const { data, error } = await supabase
  .from("african_football_clubs")
  .update({
    default_language: "en",
    supported_languages: ["en", "fr"],
  })
  .eq("club_slug", "rayon_sports_rw")
  .select("club_slug, default_language, supported_languages")
  .maybeSingle();

if (error) {
  console.error("Update failed:", error.message);
  process.exit(1);
}

console.log("✅ Club language updated:", JSON.stringify(data, null, 2));
