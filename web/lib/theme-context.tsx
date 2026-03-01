"use client";

import {
  createContext,
  type ReactNode,
  useContext,
  useEffect,
  useState,
} from "react";

type Mode = "standard" | "compact";

interface ThemeContextValue {
  mode: Mode;
  setMode: (mode: Mode) => void;
}

const ThemeContext = createContext<ThemeContextValue>({
  mode: "standard",
  setMode: () => {},
});

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [mode, setMode] = useState<Mode>("standard");

  useEffect(() => {
    if (mode === "compact") {
      document.body.classList.add("compact-mode");
    } else {
      document.body.classList.remove("compact-mode");
    }
  }, [mode]);

  return (
    <ThemeContext.Provider value={{ mode, setMode }}>
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  return useContext(ThemeContext);
}
