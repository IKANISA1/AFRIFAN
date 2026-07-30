import { getClubProfile } from "@/lib/data/public";
import { buildPageMetadata } from "@/lib/metadata";
import { getSiteCopy } from "@/lib/site-copy";
import { SearchPageClient } from "@/components/search-page-client";

export async function generateMetadata() {
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);
  return buildPageMetadata({
    title: copy.pages.searchPage.metaTitle,
    description: copy.pages.searchPage.metaDescription,
    path: "/search",
  });
}

interface SearchPageProps {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}

function normalizeQueryValue(value: string | string[] | undefined) {
  if (Array.isArray(value)) {
    return value[0]?.trim() ?? "";
  }

  return value?.trim() ?? "";
}

export default async function SearchPage({ searchParams }: SearchPageProps) {
  const params = await searchParams;
  const query = normalizeQueryValue(params.q);
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);

  return (
    <SearchPageClient
      initialQuery={query}
      locale={club.defaultLanguage}
      copy={{
        search: copy.search,
        title: copy.common.findItFast,
        intro: copy.common.searchIntro,
        placeholder: copy.common.searchPlaceholder,
        noResults: copy.common.noResults,
        trySearchHint: copy.common.trySearchHint,
      }}
    />
  );
}
