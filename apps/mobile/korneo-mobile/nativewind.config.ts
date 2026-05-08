/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./app/**/*.{js,jsx,ts,tsx}', './components/**/*.{js,jsx,ts,tsx}'],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
        orbitron: ['Orbitron', 'sans-serif'],
      },
      colors: {
        primary: '#0A0A0F',
        secondary: '#1A1A2E',
        accent: '#00D9FF',
        'accent-2': '#00FF88',
        glow: '#0080FF',
        text: '#E0E0E0',
        'text-muted': '#8892a0',
        warning: '#FF6B00',
        success: '#00FF88',
        danger: '#FF3366',
        border: 'rgba(0, 217, 255, 0.15)',
      },
      boxShadow: {
        'glow-cyan': '0 0 20px rgba(0, 217, 255, 0.3), 0 0 40px rgba(0, 217, 255, 0.1)',
        'glow-green': '0 0 20px rgba(0, 255, 136, 0.3), 0 0 40px rgba(0, 255, 136, 0.1)',
        'card': '0 4px 20px rgba(0, 0, 0, 0.4), inset 0 1px 0 rgba(255, 255, 255, 0.05)',
      },
      animation: {
        'glow-pulse': 'glowPulse 2s ease-in-out infinite',
        'blink-red': 'blinkRed 1.5s ease-in-out infinite',
        'pulse': 'pulse 2s infinite',
      },
      keyframes: {
        glowPulse: {
          '0%, 100%': { opacity: '0.5' },
          '50%': { opacity: '1' },
        },
        blinkRed: {
          '0%, 100%': { background: 'var(--gradient-card)' },
          '50%': { background: 'rgba(255, 51, 102, 0.15)' },
        },
        pulse: {
          '0%, 100%': { opacity: '1' },
          '50%': { opacity: '0.7' },
        },
      },
    },
  },
  plugins: [],
};

