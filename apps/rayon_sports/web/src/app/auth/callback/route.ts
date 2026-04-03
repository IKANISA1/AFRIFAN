import { NextResponse } from "next/server";
import { getServerSupabase } from "@/lib/supabase/server";

function resolveNextPath(nextValue: string | null) {
  if (typeof nextValue !== "string" || !nextValue.startsWith("/")) {
    return "/admin";
  }

  return nextValue;
}

export async function GET(request: Request) {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const nextPath = resolveNextPath(url.searchParams.get("next"));

  if (code == null) {
    return NextResponse.redirect(
      new URL(`${nextPath}?error=missing_auth_code`, url.origin),
    );
  }

  const supabase = await getServerSupabase();
  if (supabase == null) {
    return NextResponse.redirect(
      new URL(`${nextPath}?error=supabase_not_configured`, url.origin),
    );
  }

  const { error } = await supabase.auth.exchangeCodeForSession(code);
  if (error) {
    return NextResponse.redirect(
      new URL(`${nextPath}?error=auth_callback_failed`, url.origin),
    );
  }

  return NextResponse.redirect(new URL(nextPath, url.origin));
}
