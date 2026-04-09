import type { Config } from 'tailwindcss';
import { fontFamily } from 'tailwindcss/defaultTheme';

const config: Config = {
  content: ['./app/**/*.{js,jsx,ts,tsx}', './components/**/*.{js,jsx,ts,tsx}'],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter', ...fontFamily.sans],
        orbitron: ['Orbitron', ...fontFamily.sans],
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
        danger: '#FF3366',
      },
      boxShadow: {
        'glow-cyan': '0 0 20px rgba(0, 217, 255, 0.3), 0 0 40px rgba(0, 217, 255, 0.1)',
        'glow-green': '0 0 20px rgba(0, 255, 136, 0.3), 0 0 40px rgba(0, 255, 136, 0.1)',
        'card': '0 4px 20px rgba(0, 0, 0, 0.4), inset 0 1px 0 rgba(255, 255, 255, 0.05)',
      },
      animation: {
        'glow-pulse': 'glowPulse 2s ease-in-out infinite',
        'slide-up': 'slideUp 0.3s ease',
      },
      keyframes: {
        glowPulse: {
          '0%, 100%': { opacity: '0.5', boxShadow: '0 0 0 rgba(0,217,255,0)' },
          '50%': { opacity: '1', boxShadow: '0 0 20px rgba(0,217,255,0.5)' },
        },
        slideUp: {
          '0%': { transform: 'translateY(100%)' },
          '100%': { transform: 'translateY(0)' },
        },
      },
    },
  },
  plugins: [],
};

export default config;

