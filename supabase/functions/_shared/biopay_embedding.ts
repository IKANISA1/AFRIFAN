export const BioPay_EMBEDDING_LENGTH = 192;

export function normalizeBioPayEmbedding(input: unknown): number[] {
  if (!Array.isArray(input) || input.length !== BioPay_EMBEDDING_LENGTH) {
    throw new Error(
      `BioPay embedding must contain exactly ${BioPay_EMBEDDING_LENGTH} values.`,
    );
  }

  return input.map((value) => {
    const numberValue = typeof value === "number" ? value : Number(value);
    if (!Number.isFinite(numberValue)) {
      throw new Error("BioPay embedding contains a non-numeric value.");
    }
    return numberValue;
  });
}
