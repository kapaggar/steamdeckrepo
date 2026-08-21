declare module "*.svg" {
  const content: string;
  export default content;
}

export interface FocusStatus {
  ollama: boolean;
  webui: boolean;
  message: string;
}

export interface FocusResult {
  ok: boolean;
  message: string;
}
