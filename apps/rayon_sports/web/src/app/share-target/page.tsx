import { resolveFanAppHref, siteConfig } from "@/lib/config";
import { buildPageMetadata } from "@/lib/metadata";
import { ShareTargetContent } from "./share-target-content";
import { boundedSharedText, safeSharedWebUrl } from "./share-target-input";

export const metadata = buildPageMetadata({
  title: `Shared into ${siteConfig.shortTitle}`,
  description: "Review shared content and continue inside the supporter app flow.",
  path: "/share-target",
  robots: {
    index: false,
    follow: false,
  },
});

interface ShareTargetPageProps {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}

export default async function ShareTargetPage({
  searchParams,
}: ShareTargetPageProps) {
  const params = await searchParams;
  const title = boundedSharedText(params.title, 160);
  const text = boundedSharedText(params.text, 1000);
  const suppliedUrl = boundedSharedText(params.url, 2048);
  const url = safeSharedWebUrl(params.url);
  const query = [title, text, url].filter(Boolean).join(" ").slice(0, 2200);

  return (
    <ShareTargetContent
      appHref={resolveFanAppHref()}
      query={query}
      sharedTitle={title}
      sharedText={text}
      sharedUrl={url}
      unsafeUrlOmitted={Boolean(suppliedUrl && !url)}
      shortTitle={siteConfig.shortTitle}
    />
  );
}
