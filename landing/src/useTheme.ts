import { useEffect, useState } from "react";

type Theme = "light" | "dark";
const preferenceKey = "told-theme";
function parsePreference(value: string | null): Theme | null {
  return value === "light" || value === "dark" ? value : null;
}
function savedPreference(): Theme | null {
  try {
    return parsePreference(localStorage.getItem(preferenceKey));
  } catch {
    return null;
  }
}
export function useTheme() {
  const [preference, setPreference] = useState(savedPreference);
  const [systemTheme, setSystemTheme] = useState<Theme>(() =>
    window.matchMedia("(prefers-color-scheme: dark)").matches
      ? "dark"
      : "light",
  );
  const theme = preference ?? systemTheme;
  useEffect(() => {
    const media = window.matchMedia("(prefers-color-scheme: dark)");
    const updateSystem = () => setSystemTheme(media.matches ? "dark" : "light");
    const syncPreference = (event: StorageEvent) => {
      if (event.key === preferenceKey || event.key === null)
        setPreference(parsePreference(event.newValue));
    };
    updateSystem();
    media.addEventListener("change", updateSystem);
    window.addEventListener("storage", syncPreference);
    return () => {
      media.removeEventListener("change", updateSystem);
      window.removeEventListener("storage", syncPreference);
    };
  }, []);
  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    document
      .querySelector('meta[name="theme-color"]')
      ?.setAttribute("content", theme === "dark" ? "#111210" : "#f7f7f4");
  }, [theme]);
  function toggleTheme() {
    const next = theme === "dark" ? "light" : "dark";
    setPreference(next);
    try {
      localStorage.setItem(preferenceKey, next);
    } catch {
      /* Session-only preference when storage is unavailable. */
    }
  }
  return { theme, toggleTheme };
}
