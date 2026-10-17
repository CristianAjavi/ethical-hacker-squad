import { NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase/admin";

// Called daily by Vercel Cron (vercel.json): moves expired trials back to free.
export async function GET(req: Request) {
  if (req.headers.get("authorization") !== `Bearer ${process.env.CRON_SECRET}`) {
    return new Response("unauthorized", { status: 401 });
  }
  await supabaseAdmin.from("profiles").update({ plan: "free" }).eq("plan", "trial");
  return NextResponse.json({ ok: true });
}
