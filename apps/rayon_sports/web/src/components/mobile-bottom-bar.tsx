import Link from "next/link";
import { Ticket, User } from "lucide-react";
import { ui } from "@/ui-kit";
import { resolveFanAppHref } from "@/lib/config";

export function MobileBottomBar() {
  return (
    <div
      className={`fixed bottom-0 left-0 right-0 z-50 pb-[env(safe-area-inset-bottom)] md:hidden ${ui.shellBar}`}
    >
      <div className="flex items-center justify-center gap-3 px-4 py-2.5">
        <Link
          href="/tickets"
          prefetch={false}
          className={`${ui.buttonSecondary} flex-1 px-4 py-2.5 text-sm`}
        >
          <Ticket size={16} />
          Tickets
        </Link>
        <Link
          href={resolveFanAppHref()}
          prefetch={false}
          className={`${ui.buttonPrimary} cta-glow flex-1 px-4 py-2.5 text-sm`}
        >
          <User size={16} />
          Fan app
        </Link>
      </div>
    </div>
  );
}
