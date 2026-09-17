# Authored vibrato and measured modulation

Status: `in_progress`

Implement topic 56 with authored audible width/rate, reference playback, TAB/staff/curve presentation, periodic-contour measurement and a substantive bilingual progressive lesson. Use the existing audio coordinator/contour; no new capture pipeline or callback work. Preserve tuning/position semantics and immutable historical results.

The system must distinguish known flat/wrong/irregular modulation from unavailable signal, and must not claim that sound identifies a finger, string or physical gesture. Choose conservative width/rate/frequency bounds from independent synthetic PCM and record real-instrument checks as pending_user. Explicitly separate pitch/rhythm of the initial attack from modulation measurements.

The authored model, reference, periodic-contour assessment, en/uk notation/results/agent exchange and five-activity lesson are implemented in the working branch. Targeted synthetic and course-matrix checks pass; full suites and release/CI acceptance remain open. Same-agent review, en/uk accessibility, root-only signed Release and exact-head CI/merge are required. Do not build a local Debug app. Long legato chains and advanced gestures remain separate required work for later course topics.
