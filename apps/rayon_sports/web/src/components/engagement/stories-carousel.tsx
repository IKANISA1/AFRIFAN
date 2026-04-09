"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Image from "next/image";
import { ChevronLeft, ChevronRight, Pause, Play, Volume2, VolumeX, X } from "lucide-react";
import { cn } from "@/lib/utils";

/* ── Types ── */

export interface StorySlide {
  id: string;
  type: "image" | "video";
  src: string;
  /** Poster image for video slides */
  poster?: string;
  /** Duration in ms (default: 5000 for images, video duration for video) */
  durationMs?: number;
  /** Overlay text content */
  caption?: string;
  /** Small label above caption */
  eyebrow?: string;
  /** CTA button */
  cta?: { label: string; href: string };
}

export interface Story {
  id: string;
  title: string;
  /** Thumbnail for the ring preview */
  thumbnail: string;
  /** Whether this story has been viewed */
  viewed?: boolean;
  slides: StorySlide[];
  author?: string;
  publishedAt?: string;
}

interface StoriesCarouselProps {
  stories: Story[];
  className?: string;
}

/* ── Ring Thumbnails ── */

function StoryRing({
  story,
  onClick,
}: {
  story: Story;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex w-[72px] flex-col items-center gap-1.5 sm:w-20"
      aria-label={`View ${story.title} story`}
    >
      <div
        className={cn(
          "flex h-16 w-16 items-center justify-center rounded-full p-[3px] sm:h-[72px] sm:w-[72px]",
          story.viewed
            ? "bg-white/15"
            : "bg-gradient-to-br from-club-accent via-club-primary to-club-accent",
        )}
      >
        <div className="relative h-full w-full overflow-hidden rounded-full border-2 border-background">
          <Image
            src={story.thumbnail}
            alt={story.title}
            fill
            sizes="72px"
            className="object-cover"
          />
        </div>
      </div>
      <p className="w-full truncate text-center text-[10px] font-medium text-white/80">
        {story.title}
      </p>
    </button>
  );
}

/* ── Progress Bar ── */

function StoryProgressBar({
  total,
  current,
  progress,
}: {
  total: number;
  current: number;
  progress: number;
}) {
  return (
    <div className="flex gap-1 px-3">
      {Array.from({ length: total }).map((_, i) => (
        <div key={i} className="h-[3px] flex-1 overflow-hidden rounded-full bg-white/25">
          <div
            className="h-full rounded-full bg-white transition-[width] duration-100 ease-linear"
            style={{
              width:
                i < current ? "100%" : i === current ? `${progress}%` : "0%",
            }}
          />
        </div>
      ))}
    </div>
  );
}

/* ── Full-screen Story Viewer ── */

function StoryViewer({
  stories,
  initialIndex,
  onClose,
}: {
  stories: Story[];
  initialIndex: number;
  onClose: () => void;
}) {
  const [storyIndex, setStoryIndex] = useState(initialIndex);
  const [slideIndex, setSlideIndex] = useState(0);
  const [progress, setProgress] = useState(0);
  const [paused, setPaused] = useState(false);
  const [muted, setMuted] = useState(true);
  const videoRef = useRef<HTMLVideoElement>(null);
  const timerRef = useRef<ReturnType<typeof setInterval>>(null);

  const story = stories[storyIndex];
  const slide = story?.slides[slideIndex];
  const slideDuration = slide?.durationMs ?? (slide?.type === "video" ? 15000 : 5000);

  /* Navigate */
  const goNext = useCallback(() => {
    if (!story) return;
    if (slideIndex < story.slides.length - 1) {
      setSlideIndex((p) => p + 1);
      setProgress(0);
    } else if (storyIndex < stories.length - 1) {
      setStoryIndex((p) => p + 1);
      setSlideIndex(0);
      setProgress(0);
    } else {
      onClose();
    }
  }, [story, slideIndex, storyIndex, stories.length, onClose]);

  const goPrev = useCallback(() => {
    if (slideIndex > 0) {
      setSlideIndex((p) => p - 1);
      setProgress(0);
    } else if (storyIndex > 0) {
      setStoryIndex((p) => p - 1);
      setSlideIndex(0);
      setProgress(0);
    }
  }, [slideIndex, storyIndex]);

  /* Auto-advance timer */
  useEffect(() => {
    if (paused) return;
    const interval = 50;
    const step = (interval / slideDuration) * 100;
    timerRef.current = setInterval(() => {
      setProgress((p) => {
        if (p >= 100) {
          goNext();
          return 0;
        }
        return p + step;
      });
    }, interval);
    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
    };
  }, [paused, slideDuration, goNext]);

  /* Reset progress on slide change */
  useEffect(() => {
    if (videoRef.current) {
      videoRef.current.currentTime = 0;
      if (!paused) videoRef.current.play().catch(() => {});
    }
  }, [slideIndex, storyIndex, paused]);

  /* Keyboard navigation */
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === "ArrowRight") goNext();
      else if (e.key === "ArrowLeft") goPrev();
      else if (e.key === "Escape") onClose();
      else if (e.key === " ") {
        e.preventDefault();
        setPaused((p) => !p);
      }
    };
    document.addEventListener("keydown", handler);
    return () => document.removeEventListener("keydown", handler);
  }, [goNext, goPrev, onClose]);

  if (!story || !slide) return null;

  return (
    <div
      className="fixed inset-0 z-[9999] flex items-center justify-center bg-black/95"
      role="dialog"
      aria-modal="true"
      aria-label={`${story.title} story viewer`}
    >
      {/* Viewer container — phone-shaped on desktop */}
      <div className="relative flex h-full w-full flex-col overflow-hidden sm:h-[92vh] sm:max-h-[820px] sm:w-[400px] sm:rounded-3xl">
        {/* Background image/video */}
        <div className="absolute inset-0">
          {slide.type === "video" ? (
            <video
              ref={videoRef}
              src={slide.src}
              poster={slide.poster}
              autoPlay
              muted={muted}
              playsInline
              loop={false}
              className="h-full w-full object-cover"
            />
          ) : (
            <Image
              src={slide.src}
              alt={slide.caption ?? story.title}
              fill
              sizes="400px"
              className="object-cover"
              priority
            />
          )}
          {/* Gradient overlays */}
          <div className="absolute inset-0 bg-gradient-to-b from-black/50 via-transparent to-black/70" />
        </div>

        {/* Top bar: progress + close */}
        <div className="relative z-10 space-y-3 pt-3">
          <StoryProgressBar
            total={story.slides.length}
            current={slideIndex}
            progress={progress}
          />
          <div className="flex items-center justify-between px-4">
            <div className="flex items-center gap-2">
              <div className="h-8 w-8 overflow-hidden rounded-full border border-white/20">
                <Image
                  src={story.thumbnail}
                  alt={story.title}
                  width={32}
                  height={32}
                  className="h-full w-full object-cover"
                />
              </div>
              <div>
                <p className="text-xs font-semibold text-white">{story.title}</p>
                {story.publishedAt && (
                  <p className="text-[10px] text-white/50">{story.publishedAt}</p>
                )}
              </div>
            </div>
            <div className="flex items-center gap-2">
              {slide.type === "video" && (
                <button
                  type="button"
                  onClick={() => setMuted((m) => !m)}
                  className="flex h-8 w-8 items-center justify-center rounded-full bg-black/30 text-white backdrop-blur-sm"
                  aria-label={muted ? "Unmute" : "Mute"}
                >
                  {muted ? <VolumeX size={16} /> : <Volume2 size={16} />}
                </button>
              )}
              <button
                type="button"
                onClick={() => setPaused((p) => !p)}
                className="flex h-8 w-8 items-center justify-center rounded-full bg-black/30 text-white backdrop-blur-sm"
                aria-label={paused ? "Play" : "Pause"}
              >
                {paused ? <Play size={16} /> : <Pause size={16} />}
              </button>
              <button
                type="button"
                onClick={onClose}
                className="flex h-8 w-8 items-center justify-center rounded-full bg-black/30 text-white backdrop-blur-sm"
                aria-label="Close story"
              >
                <X size={16} />
              </button>
            </div>
          </div>
        </div>

        {/* Touch zones */}
        <div className="relative z-10 flex flex-1">
          <button
            type="button"
            onClick={goPrev}
            className="w-1/3 cursor-default"
            aria-label="Previous slide"
          />
          <button
            type="button"
            onClick={() => setPaused((p) => !p)}
            className="w-1/3 cursor-default"
            aria-label="Pause/play"
          />
          <button
            type="button"
            onClick={goNext}
            className="w-1/3 cursor-default"
            aria-label="Next slide"
          />
        </div>

        {/* Caption overlay (bottom) */}
        <div className="relative z-10 space-y-3 px-5 pb-8">
          {slide.eyebrow && (
            <p className="font-mono text-[10px] uppercase tracking-[0.28em] text-club-accent">
              {slide.eyebrow}
            </p>
          )}
          {slide.caption && (
            <p className="font-display text-xl font-bold uppercase leading-tight text-white sm:text-2xl">
              {slide.caption}
            </p>
          )}
          {slide.cta && (
            <a
              href={slide.cta.href}
              className="inline-flex items-center gap-2 rounded-full bg-white px-5 py-2.5 text-sm font-semibold text-slate-950 transition hover:bg-white/90"
            >
              {slide.cta.label}
              <ChevronRight size={14} />
            </a>
          )}
        </div>
      </div>

      {/* Desktop arrow navigation */}
      <button
        type="button"
        onClick={goPrev}
        className="absolute left-4 hidden h-12 w-12 items-center justify-center rounded-full bg-white/10 text-white backdrop-blur-md transition hover:bg-white/20 sm:flex"
        aria-label="Previous story"
      >
        <ChevronLeft size={24} />
      </button>
      <button
        type="button"
        onClick={goNext}
        className="absolute right-4 hidden h-12 w-12 items-center justify-center rounded-full bg-white/10 text-white backdrop-blur-md transition hover:bg-white/20 sm:flex"
        aria-label="Next story"
      >
        <ChevronRight size={24} />
      </button>
    </div>
  );
}

/* ── Public Carousel Component ── */

export function StoriesCarousel({ stories, className }: StoriesCarouselProps) {
  const [viewerIndex, setViewerIndex] = useState<number | null>(null);

  if (stories.length === 0) return null;

  return (
    <>
      <div
        className={cn(
          "flex gap-3 overflow-x-auto scroll-snap-x px-1 pb-2 no-scrollbar",
          className,
        )}
      >
        {stories.map((story, i) => (
          <StoryRing key={story.id} story={story} onClick={() => setViewerIndex(i)} />
        ))}
      </div>

      {viewerIndex !== null && (
        <StoryViewer
          stories={stories}
          initialIndex={viewerIndex}
          onClose={() => setViewerIndex(null)}
        />
      )}
    </>
  );
}
