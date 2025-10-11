/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/javascript/**/*.ts',
    './app/views/**/*.erb'
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: 'hsl(var(--color-primary) / <alpha-value>)',
          light: 'hsl(var(--color-primary-light) / <alpha-value>)',
          dark: 'hsl(var(--color-primary-dark) / <alpha-value>)',
        },
        secondary: {
          DEFAULT: 'hsl(var(--color-secondary) / <alpha-value>)',
          light: 'hsl(var(--color-secondary-light) / <alpha-value>)',
          dark: 'hsl(var(--color-secondary-dark) / <alpha-value>)',
        },
        surface: {
          DEFAULT: 'hsl(var(--color-surface) / <alpha-value>)',
          elevated: 'hsl(var(--color-surface-elevated) / <alpha-value>)',
        },
        border: {
          DEFAULT: 'hsl(var(--color-border) / <alpha-value>)',
        },
        neutral: {
          DEFAULT: 'hsl(var(--color-neutral) / <alpha-value>)',
        },
        success: {
          DEFAULT: 'hsl(var(--color-success) / <alpha-value>)',
          bg: 'hsl(var(--color-success-bg) / <alpha-value>)',
        },
        warning: {
          DEFAULT: 'hsl(var(--color-warning) / <alpha-value>)',
          bg: 'hsl(var(--color-warning-bg) / <alpha-value>)',
        },
        danger: {
          DEFAULT: 'hsl(var(--color-danger) / <alpha-value>)',
          bg: 'hsl(var(--color-danger-bg) / <alpha-value>)',
        },
        info: {
          DEFAULT: 'hsl(var(--color-info) / <alpha-value>)',
          bg: 'hsl(var(--color-info-bg) / <alpha-value>)',
        },
      },
      textColor: {
        primary: 'hsl(var(--color-text-primary) / <alpha-value>)',
        secondary: 'hsl(var(--color-text-secondary) / <alpha-value>)',
        muted: 'hsl(var(--color-text-muted) / <alpha-value>)',
      },
      fontFamily: {
        sans: ['var(--font-family-sans)', 'ui-sans-serif', 'system-ui'],
        mono: ['var(--font-family-mono)', 'ui-monospace', 'monospace'],
      },
      fontSize: {
        'xs': ['0.75rem', { lineHeight: '1rem' }],
        'sm': ['0.875rem', { lineHeight: '1.25rem' }],
        'base': ['1rem', { lineHeight: '1.5rem' }],
        'lg': ['1.125rem', { lineHeight: '1.75rem' }],
        'xl': ['1.25rem', { lineHeight: '1.75rem' }],
        '2xl': ['1.5rem', { lineHeight: '2rem' }],
        '3xl': ['1.875rem', { lineHeight: '2.25rem' }],
        '4xl': ['2.25rem', { lineHeight: '2.5rem' }],
        '5xl': ['3rem', { lineHeight: '1' }],
      },
      spacing: {
        '0.5': '0.125rem',
        '1.5': '0.375rem',
        '2.5': '0.625rem',
        '3.5': '0.875rem',
      },
      borderRadius: {
        'sm': 'var(--border-radius-sm)',
        'DEFAULT': 'var(--border-radius)',
        'md': 'var(--border-radius-md)',
        'lg': 'var(--border-radius-lg)',
        'xl': 'var(--border-radius-xl)',
      },
      boxShadow: {
        'xs': 'var(--shadow-xs)',
        'sm': 'var(--shadow-sm)',
        'DEFAULT': 'var(--shadow)',
        'md': 'var(--shadow-md)',
        'lg': 'var(--shadow-lg)',
        'xl': 'var(--shadow-xl)',
      },
    },
  },
  plugins: [
    require('@tailwindcss/typography'),
    require('@tailwindcss/forms'),
    require('tailwindcss-animate'),
  ],
}
