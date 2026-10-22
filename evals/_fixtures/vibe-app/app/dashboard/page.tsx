import { redirect } from "next/navigation";
import { supabaseServer } from "@/lib/supabase/server";
import NotesClient from "./NotesClient";

export default async function Dashboard() {
  const supabase = await supabaseServer();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");
  return <NotesClient userId={user.id} />;
}
