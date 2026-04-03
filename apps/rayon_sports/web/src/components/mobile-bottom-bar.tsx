import Link from "next/link";
import { Ticket, User } from "lucide-react";

export function MobileBottomBar() {
  return (
    <div className="fixed bottom-0 left-0 right-0 z-50 border-t border-border-soft bg-surface-strong/95 backdrop-blur-xl md:hidden">
      <div className="flex items-center justify-center gap-3 px-4 py-2.5">
        <Link
          href="/tickets"
          className="flex-1 flex items-center justify-center gap-2 rounded-full border border-border-soft bg-white/5 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-white/10"
        >
          <Ticket size={16} />
          Tickets
        </Link>
        <Link
          href="/app"
          className="flex-1 flex items-center justify-center gap-2 rounded-full bg-club-primary px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-club-primary-light cta-glow"
        >
          <User size={16} />
          Fan portal
        </Link>
      </div>
    </div>
  );
}
