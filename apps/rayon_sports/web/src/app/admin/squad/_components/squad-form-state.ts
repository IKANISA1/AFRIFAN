export type SquadForm = {
  id: string;
  expectedUpdatedAt: string;
  name: string;
  role: string;
  number: string;
  nationality: string;
  bio: string;
  imageUrl: string;
  isActive: boolean;
};

export const emptySquadForm: SquadForm = {
  id: "",
  expectedUpdatedAt: "",
  name: "",
  role: "Midfielder",
  number: "",
  nationality: "Rwanda",
  bio: "",
  imageUrl: "",
  isActive: true,
};

export const positionColors: Record<string, string> = {
  Goalkeeper: "admin-status-warning",
  Defender: "admin-status-success",
  Midfielder: "admin-status-info",
  Forward: "admin-status-danger",
};

export function positionColor(role: string) {
  const key = Object.keys(positionColors).find((item) =>
    role.toLowerCase().includes(item.toLowerCase()),
  );
  return positionColors[key ?? "Midfielder"] ?? positionColors.Midfielder;
}
