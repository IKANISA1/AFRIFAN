"use client";

import { useState } from "react";
import { cn } from "@/lib/utils";

interface QuizQuestion {
  id: string;
  question: string;
  options: string[];
  correctIndex: number;
  explanation?: string;
}

interface MatchQuizProps {
  matchTitle: string;
  questions: QuizQuestion[];
  fatReward?: number;
}

/**
 * Match-day quiz — 3 quick knowledge questions about the upcoming match.
 * Awards FET tokens for correct answers. Results shown after completion.
 */
export function MatchQuiz({
  matchTitle,
  questions,
  fatReward = 25,
}: MatchQuizProps) {
  const [current, setCurrent] = useState(0);
  const [answers, setAnswers] = useState<(number | null)[]>(
    new Array(questions.length).fill(null),
  );
  const [showResults, setShowResults] = useState(false);

  const question = questions[current];
  const isAnswered = answers[current] !== null;
  const correctCount = answers.filter(
    (a, i) => a === questions[i]?.correctIndex,
  ).length;

  function selectAnswer(optionIndex: number) {
    if (isAnswered) return;
    const next = [...answers];
    next[current] = optionIndex;
    setAnswers(next);
  }

  function nextQuestion() {
    if (current < questions.length - 1) {
      setCurrent(current + 1);
    } else {
      setShowResults(true);
    }
  }

  if (showResults) {
    const totalFat = correctCount * fatReward;
    const perfect = correctCount === questions.length;

    return (
      <div className="glass-panel rounded-[30px] p-5 sm:p-6 text-center">
        <p className="font-mono text-[10px] uppercase tracking-[0.28em] text-club-accent">
          Quiz complete
        </p>
        <p className="mt-3 text-4xl">{perfect ? "🏆" : correctCount > 0 ? "⚽" : "😅"}</p>
        <p className="mt-3 font-display text-2xl font-bold text-white sm:text-3xl">
          {correctCount} of {questions.length} correct
        </p>
        <p className="mt-2 text-sm text-slate-300">
          {perfect
            ? "Perfect score! You know your club inside out."
            : correctCount > 0
              ? "Solid knowledge! Keep following the squad."
              : "Tough quiz — check the pre-match build up!"}
        </p>
        {totalFat > 0 && (
          <div className="mt-4 inline-flex rounded-full bg-club-accent/15 px-4 py-2 text-sm font-bold text-club-accent">
            +{totalFat} points earned
          </div>
        )}
      </div>
    );
  }

  if (!question) return null;

  return (
    <div className="glass-panel rounded-[30px] p-5 sm:p-6">
      <div className="flex items-center justify-between gap-3">
        <p className="font-mono text-[10px] uppercase tracking-[0.28em] text-club-accent">
          Match quiz
        </p>
        <span className="rounded-full bg-white/8 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] text-slate-300">
          {current + 1}/{questions.length}
        </span>
      </div>
      <p className="mt-1 text-xs text-slate-400">{matchTitle}</p>

      {/* Progress dots */}
      <div className="mt-4 flex gap-1.5">
        {questions.map((_, i) => (
          <div
            key={`dot-${questions[i]?.id ?? i}`}
            className={cn(
              "h-1.5 flex-1 rounded-full transition-colors",
              i < current
                ? answers[i] === questions[i]?.correctIndex
                  ? "bg-emerald-400"
                  : "bg-rose-400"
                : i === current
                  ? "bg-club-accent"
                  : "bg-white/10",
            )}
          />
        ))}
      </div>

      <p className="mt-5 text-base font-semibold leading-7 text-white">
        {question.question}
      </p>

      <div className="mt-4 grid gap-2">
        {question.options.map((option, i) => {
          const selected = answers[current] === i;
          const correct = i === question.correctIndex;
          const revealed = isAnswered;

          return (
            <button
              type="button"
              key={`${question.id}-opt-${i}`}
              onClick={() => selectAnswer(i)}
              disabled={isAnswered}
              className={cn(
                "rounded-2xl border px-4 py-3 text-left text-sm font-medium transition",
                revealed && correct
                  ? "border-emerald-400/30 bg-emerald-500/12 text-emerald-200"
                  : revealed && selected && !correct
                    ? "border-rose-400/30 bg-rose-500/12 text-rose-200"
                    : selected
                      ? "border-club-accent/30 bg-club-accent/10 text-white"
                      : "border-white/8 bg-white/4 text-slate-200 hover:bg-white/8",
              )}
            >
              <span className="mr-2 inline-flex h-6 w-6 items-center justify-center rounded-full bg-white/8 text-[10px] font-bold uppercase">
                {String.fromCharCode(65 + i)}
              </span>
              {option}
            </button>
          );
        })}
      </div>

      {isAnswered && question.explanation && (
        <p className="mt-3 rounded-xl bg-white/4 px-3 py-2 text-xs leading-5 text-slate-300">
          💡 {question.explanation}
        </p>
      )}

      {isAnswered && (
        <button
          type="button"
          onClick={nextQuestion}
          className="mt-4 w-full rounded-full bg-club-primary py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light"
        >
          {current < questions.length - 1 ? "Next question" : "See results"}
        </button>
      )}
    </div>
  );
}
