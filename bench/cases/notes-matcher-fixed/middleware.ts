import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

// Identical to ../notes-matcher/middleware.ts in every line but the matcher.
export function middleware(request: NextRequest) {
  const session = request.cookies.get("session");
  if (!session) {
    return NextResponse.redirect(new URL("/login", request.url));
  }
  return NextResponse.next();
}

// The standard Next.js matcher, excluding only static assets. Route handlers
// under app/api/ DO reach the middleware here. A check that flags this is a
// check nobody can use: this is the idiom almost every Next.js app ships.
export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"],
};
