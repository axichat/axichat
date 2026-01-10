/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}", "./public/**/*.html"],
  theme: {
    extend: {
      fontFamily: {
        display: ["Gabarito", "ui-sans-serif", "system-ui"],
        body: ["Inter", "ui-sans-serif", "system-ui"],
      },
      colors: {
        ink: {
          50: "#f7f7f7",
          100: "#ededed",
          200: "#d6d6d6",
          300: "#b5b5b5",
          400: "#8f8f8f",
          500: "#6b6b6b",
          600: "#4f4f4f",
          700: "#353535",
          800: "#1f1f1f",
          900: "#0c0c0c",
        },
      },
      boxShadow: {
        glow: "0 0 0 1px rgba(255,255,255,0.06), 0 30px 60px rgba(0,0,0,0.45)",
      },
      keyframes: {
        fadeUp: {
          "0%": { opacity: "0", transform: "translateY(16px)" },
          "100%": { opacity: "1", transform: "translateY(0)" },
        },
        floatSlow: {
          "0%": { transform: "translateY(0px)" },
          "50%": { transform: "translateY(-10px)" },
          "100%": { transform: "translateY(0px)" },
        },
      },
      animation: {
        fadeUp: "fadeUp 0.8s ease-out both",
        floatSlow: "floatSlow 8s ease-in-out infinite",
      },
    },
  },
  plugins: [],
};
