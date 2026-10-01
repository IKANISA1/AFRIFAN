import "@testing-library/jest-dom/vitest";
import { vi } from "vitest";

// Vitest exercises actual server guards outside Next's react-server resolver.
// Only its import marker is replaced; application authorization remains real.
vi.mock("server-only", () => ({}));
