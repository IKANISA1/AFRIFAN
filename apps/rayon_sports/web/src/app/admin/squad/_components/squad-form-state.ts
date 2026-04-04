export type SquadForm = {
  id: string;
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
  name: "",
  role: "Midfielder",
  number: "",
  nationality: "Rwanda",
  bio: "",
  imageUrl: "",
  isActive: true,
};

export const positionColors: Record<string, string> = {
  Goalkeeper: "bg-amber-500/15 text-amber-400 border-amber-500/30",
  Defender: "bg-emerald-500/15 text-emerald-400 border-emerald-500/30",
  Midfielder: "bg-club-accent/15 text-club-accent border-club-accent/30",
  Forward: "bg-rose-500/15 text-rose-300 border-rose-500/30",
};

export function positionColor(role: string) {
  const key = Object.keys(positionColors).find((item) =>
    role.toLowerCase().includes(item.toLowerCase()),
  );
  return positionColors[key ?? "Midfielder"] ?? positionColors.Midfielder;
}
