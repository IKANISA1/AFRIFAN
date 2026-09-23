export type StandingForm = {
  id: string;
  expectedUpdatedAt: string;
  position: string;
  club: string;
  clubSlug: string;
  played: string;
  goalDifference: string;
  points: string;
  form: string;
};

export const emptyForm: StandingForm = {
  id: "",
  expectedUpdatedAt: "",
  position: "",
  club: "",
  clubSlug: "",
  played: "0",
  goalDifference: "0",
  points: "0",
  form: "",
};
