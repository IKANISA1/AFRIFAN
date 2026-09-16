import { act, cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { TicketVerifier } from "./ticket-verifier";

vi.mock("../../_components/venue-shell-client", () => ({ useVenueOnline: () => true }));

const credential = "99460000-0000-4000-8000-000000000726";
const code = (id = credential, version = 1, time = 1800000000) =>
  `AFC1.${id}.${version}.${time}.12345678`;
const admitted = { status: "admitted", code: "admitted", ticket_number: "000000000726" };
const reply = (result: Record<string, unknown> = admitted) => new Response(JSON.stringify({ data: { result } }), {
  status: 200, headers: { "Content-Type": "application/json" },
});
const fetcher = vi.fn<typeof fetch>();
const bodies = () => fetcher.mock.calls.map(([, init]) => JSON.parse(String(init?.body)));
const enter = (value = code()) => fireEvent.change(screen.getByLabelText("External scanner or code"), { target: { value } });
const submit = () => fireEvent.click(screen.getByRole("button", { name: "Verify code" }));
const failed = () => screen.findByRole("button", { name: "Clear result" });

beforeEach(() => { fetcher.mockReset(); vi.stubGlobal("fetch", fetcher); });
afterEach(() => { cleanup(); vi.useRealTimers(); vi.unstubAllGlobals(); vi.restoreAllMocks(); });

describe("venue ticket verification recovery", () => {
  it("recovers an uncertain admission with the original operation and a current rotating code", async () => {
    fetcher.mockRejectedValueOnce(new TypeError("Failed to fetch")).mockResolvedValueOnce(reply());
    render(<TicketVerifier gates={["NORTH"]} />);
    enter(); submit(); await failed();
    expect(screen.queryByText("Admit supporter")).not.toBeInTheDocument();
    enter(code(credential, 1, 1800000030)); submit();
    await screen.findByText("Admit supporter");
    const requests = bodies();
    expect(requests[1].operation_id).toBe(requests[0].operation_id);
    expect(requests[1].ticket_code).not.toBe(requests[0].ticket_code);
  });

  it("explains that a failed response leaves the admission result uncertain", async () => {
    fetcher.mockRejectedValueOnce(new TypeError("Failed to fetch"));
    render(<TicketVerifier gates={["NORTH"]} />);
    enter(); submit(); await failed();
    expect(screen.getByText("Result not confirmed")).toBeInTheDocument();
    expect(screen.getByText(/Do not admit yet/)).toBeInTheDocument();
  });

  it("retains recovery after clearing the message and checking a different ticket", async () => {
    fetcher.mockRejectedValueOnce(new TypeError("Network lost"))
      .mockResolvedValueOnce(reply()).mockResolvedValueOnce(reply());
    render(<TicketVerifier gates={["NORTH"]} />);
    enter(); submit(); await failed();
    fireEvent.click(screen.getByRole("button", { name: "Clear result" }));
    enter(code("99460000-0000-4000-8000-000000000727")); submit();
    await screen.findByText("Admit supporter");
    enter(code(credential, 1, 1800000030)); submit();
    await waitFor(() => expect(fetcher).toHaveBeenCalledTimes(3));
    await screen.findByText("Admit supporter");
    const requests = bodies();
    expect(requests[1].operation_id).not.toBe(requests[0].operation_id);
    expect(requests[2].operation_id).toBe(requests[0].operation_id);
  });

  it.each(["gate", "version"])("does not reuse an uncertain operation for a changed %s", async (changed) => {
    fetcher.mockRejectedValueOnce(new TypeError("Network lost")).mockResolvedValueOnce(reply());
    render(<TicketVerifier gates={["NORTH", "SOUTH"]} />);
    enter(); submit(); await failed();
    if (changed === "gate") fireEvent.change(screen.getByLabelText("Active gate"), { target: { value: "SOUTH" } });
    else enter(code(credential, 2));
    submit(); await screen.findByText("Admit supporter");
    const requests = bodies();
    expect(requests[1].operation_id).not.toBe(requests[0].operation_id);
  });

  it("starts a new scan after a definitive decision instead of replaying admission", async () => {
    fetcher.mockResolvedValueOnce(reply()).mockResolvedValueOnce(reply({ ...admitted, status: "rejected", code: "already_used" }));
    render(<TicketVerifier gates={["NORTH"]} />);
    enter(); submit(); await screen.findByText("Admit supporter");
    enter(); submit(); await screen.findByText("Ticket already used");
    const requests = bodies();
    expect(requests[1].operation_id).not.toBe(requests[0].operation_id);
  });

  it("sends only one request for overlapping submissions and locks the request inputs", async () => {
    let resolve!: (value: Response) => void;
    fetcher.mockReturnValueOnce(new Promise<Response>((done) => { resolve = done; }));
    render(<TicketVerifier gates={["NORTH"]} />);
    enter();
    const button = screen.getByRole("button", { name: "Verify code" });
    act(() => { button.click(); button.click(); });
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(screen.getByLabelText("Active gate")).toBeDisabled();
    expect(screen.getByLabelText("External scanner or code")).toBeDisabled();
    await act(async () => { resolve(reply()); });
    expect(screen.getByLabelText("Active gate")).toBeEnabled();
  });

  it("keeps the operation across an expired-code response and malformed success payload", async () => {
    fetcher.mockResolvedValueOnce(new Response(JSON.stringify({ error: "Expired" }), { status: 409 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ data: { result: {} } }), { status: 200 }))
      .mockResolvedValueOnce(reply());
    render(<TicketVerifier gates={["NORTH"]} />);
    enter(); submit(); await failed();
    enter(code(credential, 1, 1800000030)); submit(); await failed();
    enter(code(credential, 1, 1800000060)); submit(); await screen.findByText("Admit supporter");
    expect(new Set(bodies().map(body => body.operation_id)).size).toBe(1);
  });

  it("bounds a stalled request and recovers its original operation after timeout", async () => {
    vi.useFakeTimers();
    fetcher.mockImplementationOnce((_input, init) => new Promise((_resolve, reject) => {
      init?.signal?.addEventListener("abort", () => reject(new DOMException("Aborted", "AbortError")));
    })).mockResolvedValueOnce(reply({ ...admitted, replayed: true }));
    render(<TicketVerifier gates={["NORTH"]} />);
    enter(); submit();
    await act(async () => { await vi.advanceTimersByTimeAsync(30_000); });
    expect(screen.getByText("Result not confirmed")).toBeInTheDocument();
    expect(screen.getByText(/The check timed out/)).toBeInTheDocument();
    await act(async () => { submit(); });
    expect(screen.getByText("Admit supporter")).toBeInTheDocument();
    expect(screen.getByText(/Original check recovered/)).toBeInTheDocument();
    expect(bodies()[1].operation_id).toBe(bodies()[0].operation_id);
  });

  it("keeps a confirmed decision even when device vibration fails", async () => {
    vi.stubGlobal("navigator", { ...navigator, vibrate: () => { throw new Error("Unsupported feedback"); } });
    fetcher.mockResolvedValueOnce(reply());
    render(<TicketVerifier gates={["NORTH"]} />);
    enter(); submit(); await screen.findByText("Admit supporter");
    expect(screen.queryByText("Result not confirmed")).not.toBeInTheDocument();
    expect(screen.queryByText("Check not completed")).not.toBeInTheDocument();
  });
});
