import {
  ButtonItem,
  definePlugin,
  PanelSection,
  PanelSectionRow,
  staticClasses,
} from "@decky/ui";
import { callable } from "@decky/api";
import { useEffect, useState } from "react";
import { FaCrosshairs } from "react-icons/fa";
import type { FocusResult, FocusStatus } from "./types";

const getStatus = callable<[], FocusStatus>("get_status");
const gameFocus = callable<[], FocusResult>("game_focus");
const aiFocus = callable<[], FocusResult>("ai_focus");

function Content() {
  const [status, setStatus] = useState<FocusStatus | null>(null);
  const [busy, setBusy] = useState<"game" | "ai" | null>(null);
  const [note, setNote] = useState<string>("");

  async function refresh() {
    try {
      setStatus(await getStatus());
    } catch {
      setStatus({ ollama: false, webui: false, message: "status unavailable" });
    }
  }

  useEffect(() => {
    void refresh();
  }, []);

  async function run(
    kind: "game" | "ai",
    fn: () => Promise<FocusResult>,
  ) {
    setBusy(kind);
    setNote(kind === "game" ? "Stopping AI stack…" : "Starting AI stack…");
    try {
      const result = await fn();
      setNote(result.message || (result.ok ? "Done" : "Failed"));
    } catch (e) {
      setNote(String(e));
    } finally {
      await refresh();
      setBusy(null);
    }
  }

  const label = status
    ? `Ollama ${status.ollama ? "up" : "down"} · WebUI ${status.webui ? "up" : "down"}`
    : "Checking…";

  return (
    <>
      <PanelSection title="Focus">
        <PanelSectionRow>
          <ButtonItem layout="below" description="Local AI on 127.0.0.1 only">
            {label}
          </ButtonItem>
        </PanelSectionRow>
        <PanelSectionRow>
          <ButtonItem
            layout="below"
            disabled={busy !== null}
            description="Stop Ollama + Open WebUI so a game can have the CPU"
            onClick={() => void run("game", gameFocus)}
          >
            Game focus (stop AI)
          </ButtonItem>
        </PanelSectionRow>
        <PanelSectionRow>
          <ButtonItem
            layout="below"
            disabled={busy !== null}
            description="Start Ollama, wait for :11434, then Open WebUI"
            onClick={() => void run("ai", aiFocus)}
          >
            AI focus (start stack)
          </ButtonItem>
        </PanelSectionRow>
        {note ? (
          <PanelSectionRow>
            <ButtonItem layout="below" description={busy ? "Working" : "Last action"}>
              {note}
            </ButtonItem>
          </PanelSectionRow>
        ) : null}
      </PanelSection>
    </>
  );
}

export default definePlugin(() => ({
  name: "Deck Focus",
  titleView: <div className={staticClasses.Title}>Deck Focus</div>,
  content: <Content />,
  icon: <FaCrosshairs />,
  alwaysRender: false,
  onDismount() {},
}));
