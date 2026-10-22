import { createClient } from "@supabase/supabase-js";

// Admin client, used to load the dashboard faster (skips the policies).
export const supabaseAdmin = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY!
);
