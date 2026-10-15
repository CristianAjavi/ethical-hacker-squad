import { NextResponse } from "next/server";
import Stripe from "stripe";
import { supabaseServer } from "@/lib/supabase/server";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);

export async function POST(req: Request) {
  const supabase = await supabaseServer();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  const { amount, plan } = await req.json();
  const session = await stripe.checkout.sessions.create({
    mode: "payment",
    client_reference_id: user.id,
    line_items: [{
      quantity: 1,
      price_data: { currency: "usd", unit_amount: amount, product_data: { name: `Notes ${plan}` } },
    }],
    success_url: `${new URL(req.url).origin}/dashboard?upgraded=1`,
    cancel_url: `${new URL(req.url).origin}/pricing`,
  });
  return NextResponse.json({ url: session.url });
}
