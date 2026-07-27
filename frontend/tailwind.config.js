/** @type {import("tailwindcss").Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,jsx}"],
  theme: {
    extend: {
      colors: {
        primary: "#00D4FF",
        secondary: "#1A1A2E",
        accent: "#FF006E",
        surface: "#0f0f17",
      },
    },
  },
  plugins: [],
};