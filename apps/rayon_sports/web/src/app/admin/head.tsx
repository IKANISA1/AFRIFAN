const supabaseHost = process.env.NEXT_PUBLIC_SUPABASE_URL
  ? new URL(process.env.NEXT_PUBLIC_SUPABASE_URL.trim()).origin
  : null;

export default function Head() {
  if (!supabaseHost) {
    return null;
  }

  return (
    <>
      <link rel="preconnect" href={supabaseHost} />
      <link rel="dns-prefetch" href={supabaseHost} />
    </>
  );
}
