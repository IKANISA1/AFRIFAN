import { parsePaymentRefundCommand, type PaymentRefundCommand, type RefundDraftCommand } from "@/lib/data/admin/payment-refunds";

export interface RefundJournalEntry { version: 1; userId: string; clubId: string; command: PaymentRefundCommand }
const prefix = "africlub.refund-operation.v1";
function scope(userId: string, clubId: string) { return `${prefix}:${userId}:${clubId}`; }
function persist(key: string, value: string) {
  localStorage.setItem(key, value);
  if (localStorage.getItem(key) !== value) throw new Error("The original refund reference could not be saved. No command was sent.");
}
export function readPendingRefundOperation(userId: string, clubId: string): RefundJournalEntry | null {
  const raw = localStorage.getItem(`${scope(userId, clubId)}:pending`);
  if (raw === null) return null;
  let entry: RefundJournalEntry;
  try {
    const data = JSON.parse(raw) as RefundJournalEntry;
    if (data.version !== 1 || data.userId !== userId || data.clubId !== clubId) throw new Error();
    entry = { version: 1, userId, clubId, command: parsePaymentRefundCommand(data.command) };
  } catch { throw new Error("The saved refund reference needs recovery. No new command was sent."); }
  return entry;
}
export async function withRefundJournal<T>(userId: string, clubId: string, command: RefundDraftCommand | PaymentRefundCommand,
  send: (retained: PaymentRefundCommand) => Promise<T>): Promise<T> {
  if (!navigator.locks?.request) throw new Error("This browser cannot safely retain a refund command. Use a browser with secure operation locking.");
  return navigator.locks.request(scope(userId, clubId), async () => {
    const prior = readPendingRefundOperation(userId, clubId);
    let retained: PaymentRefundCommand;
    if (prior) {
      if (!("operationId" in command) || command.operationId !== prior.command.operationId
        || JSON.stringify(command) !== JSON.stringify(prior.command)) throw new Error("Check the saved operation before starting another refund command.");
      retained = prior.command;
    } else {
      retained = parsePaymentRefundCommand({ ...command, operationId: "operationId" in command ? command.operationId : crypto.randomUUID() });
      const entry: RefundJournalEntry = { version: 1, userId, clubId, command: retained };
      const serialized = JSON.stringify(entry);
      // Each original key is retained without eviction; the pending pointer is
      // written and read back before the first authoritative mutation.
      persist(`${scope(userId, clubId)}:${retained.operationId}`, serialized);
      persist(`${scope(userId, clubId)}:pending`, serialized);
    }
    const result = await send(retained);
    completeRefundOperation(userId, clubId, retained.operationId);
    return result;
  });
}
export function completeRefundOperation(userId: string, clubId: string, operationId: string) {
  const pending = readPendingRefundOperation(userId, clubId);
  if (!pending || pending.command.operationId !== operationId) throw new Error("The original refund reference changed. Check its status.");
  persist(`${scope(userId, clubId)}:${operationId}:confirmed`, "1");
  localStorage.removeItem(`${scope(userId, clubId)}:pending`);
  if (localStorage.getItem(`${scope(userId, clubId)}:pending`) !== null) throw new Error("Refund response was received; recover its saved reference before continuing.");
}
