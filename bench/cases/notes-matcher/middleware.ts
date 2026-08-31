import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

// The session gate. Everything that reaches this function is checked.
export function middleware(request: NextRequest) {
  const session = request.cookies.get("session");
  if (!session) {
    return NextResponse.redirect(new URL("/login", request.url));
  }
  return NextResponse.next();
}

// What reaches it is decided here, and this is the whole defect: the negative
// lookahead excludes `api`, so no route handler under app/api/ is ever seen by
// the middleware above. The gate is real, well written, and unreachable from
// the routes that need it.
export const config = {
  matcher: ["/((?!api|_next/static|_next/image|favicon.ico).*)"],
};
