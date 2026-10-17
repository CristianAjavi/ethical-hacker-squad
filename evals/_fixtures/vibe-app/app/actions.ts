"use server";

import { revalidatePath } from "next/cache";
import { supabaseServer } from "@/lib/supabase/server";
import { supabaseAdmin } from "@/lib/supabase/admin";

export async function createNote(formData: FormData) {
  const supabase = await supabaseServer();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Not signed in");
  await supabase.from("notes").insert({
    user_id: user.id,
    title: String(formData.get("title") ?? ""),
    body: String(formData.get("body") ?? ""),
  });
  revalidatePath("/dashboard");
}

export async function deleteNote(id: number) {
  await supabaseAdmin.from("notes").delete().eq("id", id);
  revalidatePath("/dashboard");
}
