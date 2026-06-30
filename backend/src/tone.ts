// Mirrors common_app_kit/lib/src/safety/tone_policy.dart — keep in sync when patterns change.

const BANNED_TERMS = [
  "lazy", "stupid", "idiot", "pathetic", "useless", "worthless",
  "failure", "shame", "embarrassing", "you should have",
];

const SUPPORT_CUES = [
  "you can", "it's okay", "it is okay", "you are", "great", "well done",
  "good job", "nice work", "progress", "gentle",
];

function containsBanned(text: string): boolean {
  const t = text.toLowerCase();
  return BANNED_TERMS.some((b) => t.includes(b));
}

function hasSupportiveCue(text: string): boolean {
  const t = text.toLowerCase();
  if (SUPPORT_CUES.some((c) => t.includes(c))) return true;
  return /(you('| a)?re|it('| i)?s)\b/.test(t);
}

export function isSafePracticalStep(step: string): boolean {
  const t = step.toLowerCase();
  if (t.trim().length === 0) return false;
  if (containsBanned(step)) return false;
  const metaPatterns = ["write down", "reflect on", "think about", "plan your"];
  return !metaPatterns.some((p) => t.includes(p));
}

export function isSafeCompassionateMessage(
  text: string,
  task: string,
  options?: { requireTaskMention?: boolean },
): boolean {
  const requireTaskMention = options?.requireTaskMention ?? true;
  const normalizedTask = task.trim().toLowerCase();
  if (text.trim().length === 0) return false;
  if (containsBanned(text)) return false;
  if (!hasSupportiveCue(text)) return false;
  if (requireTaskMention && normalizedTask.length > 0 &&
      !text.toLowerCase().includes(normalizedTask)) {
    return false;
  }
  return true;
}
