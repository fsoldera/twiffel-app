/**
 * Twiffel design tokens extracted from Figma
 * (file 0N24YtcP8pal5jf3E21t92, node Twiffel_Design_Tokens / 13:480).
 *
 * Opacity annotations from Figma (`50% opacity`) are encoded as 8-digit hex.
 */
export const tokens = {
  neutral: {
    'gray-50': '#f9fafb',
    'gray-100': '#f3f4f6',
    'gray-200': '#e5e7eb',
    'gray-300': '#d1d5db',
    'gray-400': '#9ca3af',
    'gray-500': '#6b7280',
    'gray-600': '#4b5563',
    'gray-700': '#374151',
    'gray-800': '#1f2937',
    'gray-900': '#111827',
    'gray-950': '#030712',
  },
  primary: {
    'primary-50': '#fffbeb',
    'primary-100': '#fef3c7',
    'primary-200': '#fde68a',
    'primary-300': '#fcd34d',
    'primary-400': '#fbbf24',
    'primary-500': '#f59e0b',
    'primary-600': '#d97706',
    'primary-700': '#b45309',
    'primary-800': '#92400e',
    'primary-900': '#78350f',
  },
  semantic: {
    'success-light': '#ecfdf5',
    'success-default': '#10b981',
    'success-dark': '#065f46',
    'error-light': '#fef2f2',
    'error-default': '#ef4444',
    'error-dark': '#991b1b',
    'warning-light': '#fffbeb',
    'warning-default': '#f59e0b',
    'warning-dark': '#92400e',
    'info-light': '#eff6ff',
    'info-default': '#3b82f6',
    'info-dark': '#1e40af',
  },
  surface: {
    'page-bg-light': '#ffffff',
    'page-bg-dark': '#111827',
    'card-surface-light': '#ffffff',
    'card-surface-dark': '#1f2937',
    'elevated-light': '#f9fafb',
    'elevated-dark': '#374151',
    'input-bg-light': '#f3f4f6',
    'input-bg-dark': '#1f2937',
    /** Figma: #000000 (50% opacity) */
    overlay: '#00000080',
  },
  text: {
    'text-primary-light': '#111827',
    'text-primary-dark': '#f9fafb',
    'text-secondary-light': '#4b5563',
    'text-secondary-dark': '#9ca3af',
    'text-tertiary-light': '#9ca3af',
    'text-tertiary-dark': '#6b7280',
    'text-disabled-light': '#d1d5db',
    'text-disabled-dark': '#374151',
    'text-on-primary': '#ffffff',
    'text-link': '#d97706',
  },
  border: {
    'border-default-light': '#e5e7eb',
    'border-default-dark': '#374151',
    'border-strong-light': '#d1d5db',
    'border-strong-dark': '#4b5563',
    'border-focus': '#d97706',
    'divider-light': '#f3f4f6',
    'divider-dark': '#1f2937',
  },
  interactive: {
    'primary-default': '#d97706',
    'primary-hover': '#b45309',
    'primary-pressed': '#92400e',
    /** Figma: #fde68a (50% opacity) */
    'primary-disabled': '#fde68a80',
    'secondary-default': '#fbbf24',
    'secondary-hover': '#f59e0b',
    'secondary-pressed': '#d97706',
    'destructive-default': '#ef4444',
    'destructive-hover': '#dc2626',
    'destructive-pressed': '#991b1b',
  },
} as const;

export type TwiffelTokens = typeof tokens;
