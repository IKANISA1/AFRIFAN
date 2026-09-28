import { getAdminPortalInitialState } from "@/lib/data/admin/bootstrap";
import { publishingLaunchUrl } from "@/lib/publishing-launch";

export const dynamic = "force-dynamic";
/** No credentials are passed in the link; no publication occurs on rendering or navigation. */
export default async function PublishingPage() {
  const state = await getAdminPortalInitialState();
  const href = publishingLaunchUrl(process.env.PUBLIC_SOURCE_CONSOLE_ENABLED,
    process.env.PUBLIC_SOURCE_CONSOLE_ORIGIN, state.access, state.controlledEvidence === true);
  return <section aria-labelledby="publishing-title">
    <header className="admin-page-header">
      <p className="admin-page-eyebrow">Club content</p>
      <h1 id="publishing-title" className="admin-page-title">Review and publish</h1>
      <p className="admin-page-copy">Inspect an approved source snapshot before separately confirming publication.</p>
    </header>
    <div className="admin-surface">
      {href ? <>
        <p>The publication workspace opens separately and checks your operator identity and club permissions again.</p>
        <a href={href} target="_blank" rel="noopener noreferrer">Open publication workspace (new tab)</a>
        <p>Opening this workspace does not publish content or authorize any payment.</p>
      </> : <p role="status">Publication access is not available for this club or this environment. No action has been submitted.</p>}
    </div>
  </section>;
}
