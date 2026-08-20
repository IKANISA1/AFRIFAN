import { describe, expect, it } from "vitest";
import {
  normalizeAdminTicketVerifierCandidate,
  normalizeAdminTicketVerifierWorkspace,
} from "./ticket-verifiers";

const ids = {
  organization: "11111111-1111-4111-8111-111111111111",
  event: "22222222-2222-4222-8222-222222222222",
  venue: "33333333-3333-4333-8333-333333333333",
  assignment: "44444444-4444-4444-8444-444444444444",
  user: "55555555-5555-4555-8555-555555555555",
};

describe("ticket verifier admin contracts", () => {
  it("normalizes bounded organization, event, gate, and shift authority", () => {
    const workspace = normalizeAdminTicketVerifierWorkspace({
      organizations: [{
        id: ids.organization,
        displayName: "Rayon Sports",
        status: "active",
      }],
      events: [{
        id: ids.event,
        organizationId: ids.organization,
        organizationName: "Rayon Sports",
        venueId: ids.venue,
        venueName: "Kigali Stadium",
        matchLabel: "Rayon Sports vs Visitors",
        status: "active",
        entryOpensAt: "2026-08-13T14:00:00Z",
        entryClosesAt: "2026-08-13T20:00:00Z",
        verificationEnabled: true,
      }],
      assignments: [{
        id: ids.assignment,
        ticketEventId: ids.event,
        organizationId: ids.organization,
        organizationName: "Rayon Sports",
        venueId: ids.venue,
        venueName: "Kigali Stadium",
        matchLabel: "Rayon Sports vs Visitors",
        userId: ids.user,
        publicUserId: "123456",
        userName: "Matchday Steward",
        gateCode: "gate_a",
        startsAt: "2026-08-13T14:00:00Z",
        endsAt: "2026-08-13T20:00:00Z",
        isActive: true,
        grantedAt: "2026-08-13T12:00:00Z",
        revokedAt: null,
        updatedAt: "2026-08-13T12:00:00Z",
      }],
    });

    expect(workspace.assignments[0]).toMatchObject({
      publicUserId: "123456",
      gateCode: "GATE_A",
      isActive: true,
    });
  });

  it("rejects duplicate assignment records", () => {
    const assignment = {
      id: ids.assignment,
      ticketEventId: ids.event,
      organizationId: ids.organization,
      organizationName: "Rayon Sports",
      venueId: ids.venue,
      venueName: "Kigali Stadium",
      matchLabel: "Rayon Sports vs Visitors",
      userId: ids.user,
      publicUserId: "123456",
      userName: "Matchday Steward",
      gateCode: null,
      startsAt: "2026-08-13T14:00:00Z",
      endsAt: "2026-08-13T20:00:00Z",
      isActive: true,
      grantedAt: "2026-08-13T12:00:00Z",
      revokedAt: null,
      updatedAt: "2026-08-13T12:00:00Z",
    };
    expect(() => normalizeAdminTicketVerifierWorkspace({
      organizations: [],
      events: [],
      assignments: [assignment, assignment],
    })).toThrow(/duplicate records/i);
  });

  it("exposes only a public id and display name for candidate selection", () => {
    expect(normalizeAdminTicketVerifierCandidate({
      userId: ids.user,
      publicUserId: "123456",
      displayName: "Matchday Steward",
      phone: "+250700000000",
    })).toEqual({
      userId: ids.user,
      publicUserId: "123456",
      displayName: "Matchday Steward",
    });
  });
});
