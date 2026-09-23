import { redirect } from "next/navigation";

// Compatibility entry only: Community owns the shared groups and ledger UI.
export default async function ContributionsRedirect({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const requested = await searchParams;
  const query = new URLSearchParams();
  if (typeof requested.club === "string") query.set("club", requested.club);
  query.set("tab", "groups");
  redirect(`/admin/community?${query.toString()}`);
}
