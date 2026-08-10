// Mirrors common_app_kit/lib/src/safety/tone_policy.dart — keep in sync when patterns change.
// Twiffel uses content-safety (validateTaskInput / isSafeContent) for verdicts.
// Compassionate/step helpers remain for kit parity / other apps.

const BANNED_TERMS = [
  "lazy", "stupid", "idiot", "pathetic", "useless", "worthless",
  "failure", "shame", "embarrassing", "you should have",
];

const SUPPORT_CUES = [
  "you can", "it's okay", "it is okay", "you are", "great", "well done",
  "good job", "nice work", "progress", "gentle",
];

export const SELF_HARM_FIX_MESSAGE =
  "If you're thinking about harming yourself, please reach out right now to " +
  "someone you trust or your local emergency or crisis line — you matter. " +
  "When you're ready, enter a small, kind decision you'd like to weigh.";

export const UNSAFE_FIX_MESSAGE =
  "I can only help with safe, everyday decisions. Please rephrase with a " +
  "positive, lawful choice you'd like to compare.";

export type TaskInputRejectionReason = "selfHarm" | "unsafe";

export interface TaskInputValidation {
  isValid: boolean;
  reason?: TaskInputRejectionReason;
  message?: string;
}

function containsBanned(text: string): boolean {
  const t = text.toLowerCase();
  return BANNED_TERMS.some((b) => t.includes(b));
}

function hasSupportiveCue(text: string): boolean {
  const t = text.toLowerCase();
  if (SUPPORT_CUES.some((c) => t.includes(c))) return true;
  return /(you('| a)?re|it('| i)?s)\b/.test(t);
}

function normalizeForSafety(text: string): string {
  return text
    .toLowerCase()
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

const SELF_HARM_PATTERNS: RegExp[] = [
  /\bsuicid(?:e|al)\b/,
  /\b(?:kill|killing|hang|hanging|harm|harming|injure|injuring)\s+(?:myself|himself|herself|yourself|themselves|ourselves)\b/,
  /\b(?:end|ending|take|taking)\s+(?:my|his|her|your|their)\s+(?:own\s+)?life\b/,
  /\bself[\s-]?(?:harm|injur)\w*/,
  /\b(?:slit|cut)\s+(?:my|his|her|your)\s+wrists?\b/,
  /\boverdos\w*/,
  /\bstarv(?:e|ing)\s+(?:myself|himself|herself)\b/,
  /\bjump(?:ing)?\s+off\s+(?:a|the)\s+(?:bridge|building|roof|cliff|ledge|balcony)\b/,
  /\bi\s+(?:want|wanna|wish|need)\s+to\s+die\b/,
  /\b(?:better\s+off\s+dead|no\s+reason\s+to\s+live|end\s+it\s+all)\b/,
  /\bkms\b/,
];

const VIOLENCE_VERBS =
  "(?:kill|murder|hurt|harm|attack|stab|shoot|strangle|poison|assault|torture|drown|choke|" +
  "beat\\s+up|suffocate|smother|mutilate|maim|slaughter|execute|behead|decapitate|lynch|" +
  "abuse|run\\s+over|shoot\\s+up|blow\\s+up)";

const VIOLENCE_TARGETS =
  "(?:him|her|them|someone|somebody|people|everyone|anyone|humans?|" +
  "my\\s+(?:wife|husband|partner|boss|neighbou?r|mom|mum|mother|dad|father|parents?|sister|brother|" +
  "son|daughter|kid|kids|child|children|baby|girlfriend|boyfriend|dog|cat|pet|family|friend|ex|" +
  "classmate|colleague|coworker|teacher|roommate)|" +
  "the\\s+(?:dog|cat|baby|kid|kids|children|neighbou?r|teacher|man|woman|guy|girl|person|" +
  "students?|class|crowd|family|school|college|mall|office|church|mosque|synagogue|store)|" +
  "that\\s+(?:guy|girl|man|woman|kid|person)|" +
  "animals?|an?\\s+animal|a\\s+(?:person|child|kid|baby|human))";

const VIOLENCE_PATTERNS: RegExp[] = [
  new RegExp(`\\b${VIOLENCE_VERBS}\\b[\\s\\w']{0,18}\\b${VIOLENCE_TARGETS}\\b`),
  /\b(?:rape|raping|rapist|molest\w*|pedophil\w*|behead\w*|decapitat\w*|genocid\w*|massacre|lynch\w*|mutilat\w*|dismember\w*)\b/,
  /\b(?:school|mass|mall|church|mosque|synagogue)\s+shooting\b/,
  /\b(?:killing|shooting|stabbing)\s+spree\b/,
  /\bhate\s+crime\b/,
];

const SEXUAL_PATTERNS: RegExp[] = [
  /\bporn(?:ography|o)?\b/,
  /\bmasturbat\w*/,
  /\b(?:blow|hand|rim)\s?jobs?\b/,
  /\b(?:fellatio|cunnilingus|intercourse|orgasm\w*|ejaculat\w*|fornicat\w*|copulat\w*)\b/,
  /\b(?:have|having|had|want|wanting|for|get|getting)\s+sex\b/,
  /\bsex\s+(?:with|chat|cam|tape|video|toys?|drive|dream)\b/,
  /\b(?:phone|cyber|anal|oral|group|casual)\s+sex\b/,
  /\bsext(?:ing)?\b/,
  /\b(?:make|making)\s+love\b/,
  /\bget(?:ting)?\s+laid\b/,
  /\b(?:send|sending|swap|post|posting)\w*\s+nudes?\b/,
  /\bnudes\b/,
  /\b(?:horny|aroused|erotica?|kinky|fetish|bdsm|bondage)\b/,
  /\b(?:escort|prostitut\w*|hooker|brothel|stripper|onlyfans)\b/,
  /\b(?:strip\s+club|lap\s+dance|sugar\s+(?:daddy|baby)|wet\s+dream)\b/,
  /\b(?:incest|bestiality|orgy|threesome|gangbang)\b/,
  /\b(?:dildo|vibrator|sex\s+toys?|fleshlight)\b/,
  /\b(?:penis|vagina|vulva|clitoris|clit|scrotum|testicl\w*|genitalia|genitals?|foreskin)\b/,
  /\b(?:dick|cock|pussy|boobs?|tits|titties|butthole)\b/,
];

const ILLEGAL_PATTERNS: RegExp[] = [
  /\b(?:make|build|3d\s?print|assemble|manufactur\w*|construct)\b[\s\w']{0,14}\b(?:gun|firearm|bomb|explosive|ied|grenade|silencer|napalm|thermite|molotov|pipe\s+bomb|nerve\s+agent|chemical\s+weapon|biological\s+weapon|poison)\b/,
  /\b(?:buy|sell|make|cook|deal|dealing|smuggl\w*|synthesi\w*|produce|traffic\w*)\b[\s\w']{0,12}\b(?:drugs?|meth(?:amphetamine)?|cocaine|heroin|fentanyl|crack|lsd|ecstasy|mdma|ketamine|opioids?)\b/,
  /\b(?:rob|robbing)\b[\s\w']{0,12}\b(?:bank|store|shop|house|person|someone)\b/,
  /\bshoplift\w*/,
  /\b(?:steal|stealing|nick)\b[\s\w']{0,12}\b(?:car|wallet|money|purse|phone|identity|credit\s+card|package)\b/,
  /\b(?:burglariz\w*|burglary|carjack\w*|pickpocket\w*|loot\w*)\b/,
  /\b(?:kidnap(?:ping)?|abduct\w*)\b/,
  /\bmoney\s+laundering\b/,
  /\blaunder\w*\s+(?:money|cash|funds)\b/,
  /\b(?:counterfeit\w*|embezzl\w*|extort\w*|blackmail\w*|bribe\w*|ponzi)\b/,
  /\b(?:credit\s+card|tax|wire|insurance|bank)\s+fraud\b/,
  /\bidentity\s+theft\b/,
  /\binsider\s+trading\b/,
  /\bforge\b[\s\w']{0,10}\b(?:check|cheque|document|passport|signature|id|licen[cs]e)\b/,
  /\bhack(?:ing|ed)?\b[\s\w']{0,12}\b(?:into|someone|account|password|email|phone|wifi|server|database|system)\b/,
  /\b(?:ddos|ransomware|keylogger|spyware|malware|phishing|sql\s+injection)\b/,
  /\b(?:steal|crack|guess)\b[\s\w']{0,8}\b(?:passwords?|credentials?)\b/,
  /\b(?:dox|doxx)\w*/,
  /\b(?:human|sex|child)\s+traffick\w*/,
  /\btraffic\w*\s+(?:people|humans|children|weapons|guns)\b/,
  /\bchild\s+(?:porn\w*|sexual|exploitation)\b/,
  /\bcsam\b/,
  /\b(?:groom|grooming)\b[\s\w']{0,10}\b(?:a\s+)?(?:child|minor|kid)\b/,
  /\b(?:underage|minor)\b[\s\w']{0,10}\b(?:sex\w*|porn\w*|nude\w*)\b/,
  /\b(?:commit\s+arson|set\s+fire\s+to|burn\s+down)\b/,
  /\bpoach\w*\s+(?:animals?|elephants?|rhinos?|wildlife)\b/,
];

const HARASSMENT_PATTERNS: RegExp[] = [
  /\b(?:harass|harassing|bully|bullying|cyberbull\w*)\b/,
  /\bstalk(?:ing)?\b[\s\w']{0,10}\b(?:my|his|her|someone|somebody|him|them|ex)\b/,
  /\bdeath\s+threats?\b/,
  /\bthreaten(?:ing)?\b[\s\w']{0,12}\bto\s+(?:kill|hurt|harm|beat|rape|stab|shoot)\b/,
];

const UNSAFE_PATTERNS: RegExp[] = [
  ...VIOLENCE_PATTERNS,
  ...SEXUAL_PATTERNS,
  ...ILLEGAL_PATTERNS,
  ...HARASSMENT_PATTERNS,
];

/** Content-safety gate (self-harm / violence / sexual / illegal / harassment). */
export function validateTaskInput(
  text: string,
  options?: { selfHarmMessage?: string; unsafeMessage?: string },
): TaskInputValidation {
  const selfHarmMessage = options?.selfHarmMessage ?? SELF_HARM_FIX_MESSAGE;
  const unsafeMessage = options?.unsafeMessage ?? UNSAFE_FIX_MESSAGE;
  const normalized = normalizeForSafety(text);
  if (normalized.length === 0) return { isValid: true };
  if (SELF_HARM_PATTERNS.some((p) => p.test(normalized))) {
    return { isValid: false, reason: "selfHarm", message: selfHarmMessage };
  }
  if (UNSAFE_PATTERNS.some((p) => p.test(normalized))) {
    return { isValid: false, reason: "unsafe", message: unsafeMessage };
  }
  return { isValid: true };
}

/** True when text passes content-safety only (no compassionate-tone rules). */
export function isSafeContent(text: string): boolean {
  return validateTaskInput(text).isValid;
}

/** First failing content-safety check across free-text fields, or ok. */
export function validateAllInputs(texts: string[]): TaskInputValidation {
  for (const text of texts) {
    const result = validateTaskInput(text);
    if (!result.isValid) return result;
  }
  return { isValid: true };
}

export function isSafePracticalStep(step: string): boolean {
  const t = step.toLowerCase();
  if (t.trim().length === 0) return false;
  if (!isSafeContent(step)) return false;
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
  if (!isSafeContent(text)) return false;
  if (containsBanned(text)) return false;
  if (!hasSupportiveCue(text)) return false;
  if (
    requireTaskMention &&
    normalizedTask.length > 0 &&
    !text.toLowerCase().includes(normalizedTask)
  ) {
    return false;
  }
  return true;
}
