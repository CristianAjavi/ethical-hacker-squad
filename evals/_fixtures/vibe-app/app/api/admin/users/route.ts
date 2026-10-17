import { NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase/admin";

// Admin panel data. /admin is behind the middleware.
export async function GET() {
  const { data } = await supabaseAdmin.from("profiles").select("id, display_name, role, plan");
  return NextResponse.json(data);
}
