import { NextResponse } from "next/server";
import { db } from "@/lib/db";
import { requireSession } from "@/lib/auth";

// This one checks for itself, which is why the gap in the matcher is easy to
// miss: a reader who opens this file first concludes the API is guarded.
export async function GET(request: Request) {
  const user = await requireSession(request);
  if (!user) return new NextResponse("unauthorized", { status: 401 });
  return NextResponse.json(await db.note.findMany({ where: { ownerId: user.id } }));
}
