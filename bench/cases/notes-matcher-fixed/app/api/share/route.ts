import { NextResponse } from "next/server";
import { db } from "@/lib/db";

// Reads any note by id. There is no session check here because the middleware
// was supposed to do it.
export async function GET(request: Request) {
  const id = new URL(request.url).searchParams.get("id");
  const note = await db.note.findUnique({ where: { id: String(id) } });
  return NextResponse.json(note);
}
