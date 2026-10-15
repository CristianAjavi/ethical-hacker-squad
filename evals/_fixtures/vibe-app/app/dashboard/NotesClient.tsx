"use client";

import { useEffect, useState } from "react";
import { supabaseAdmin } from "@/lib/supabase/admin";
import { createNote, deleteNote } from "@/app/actions";

export default function NotesClient({ userId }: { userId: string }) {
  const [notes, setNotes] = useState<{ id: number; title: string }[]>([]);
  useEffect(() => {
    supabaseAdmin.from("notes").select("id, title").eq("user_id", userId).then(({ data }) => setNotes(data ?? []));
  }, [userId]);
  return (
    <main>
      <form action={createNote}>
        <input name="title" />
        <textarea name="body" />
        <button>Add</button>
      </form>
      <ul>
        {notes.map((n) => (
          <li key={n.id}>
            {n.title} <button onClick={() => deleteNote(n.id)}>Delete</button>
          </li>
        ))}
      </ul>
    </main>
  );
}
