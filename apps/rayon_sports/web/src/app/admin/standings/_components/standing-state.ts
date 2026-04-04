export type StandingForm = {
  id: string;
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
  position: "",
  club: "",
  clubSlug: "",
  played: "0",
  goalDifference: "0",
  points: "0",
  form: "",
};
