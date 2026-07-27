/** @jsxImportSource @opentui/solid */

import { ScrollBoxRenderable, SyntaxStyle, TextareaRenderable } from "@opentui/core"
import type {
  TuiPlugin,
  TuiPluginApi,
  TuiPluginModule,
  TuiPromptInfo,
  TuiPromptRef,
} from "@opencode-ai/plugin/tui"
import { Show, createSignal, onCleanup } from "solid-js"
import { useTerminalDimensions } from "@opentui/solid"

// Requires the public TUI plugin APIs available in OpenCode 1.18.3.
const ID = "btw-side-question"
const MARKER_KEY = "opencode-btw-temp"
const MARKER_VALUE = "v1"
const DEFAULT_TIMEOUT_MS = 120_000
const SPINNER_FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
const SIDE_INSTRUCTIONS = [
  "This is a side question from the user.",
  "Answer using only what is already in the conversation context. You have no tools.",
  "Keep the answer concise and return a single response with no follow-up turn.",
  "Do not suggest running commands or re-asking in the main conversation.",
  "If the answer is not in the conversation context, say so briefly.",
].join("\n")

const command = {
  open: `${ID}.open`,
  submit: `${ID}.submit`,
  close: `${ID}.close`,
  pageUp: `${ID}.page-up`,
  pageDown: `${ID}.page-down`,
}

type PanelState = {
  visible: boolean
  loading: boolean
  sourceSessionID?: string
  generation: number
  question: string
  answer: string
  error: string
}

type Run = {
  generation: number
  sourceSessionID: string
  controller: AbortController
  forkID?: string
  timeout?: ReturnType<typeof setTimeout>
  stopped: boolean
  streaming: boolean
  cleanup?: Promise<void>
  assistantIDs: Set<string>
  partOrder: string[]
  parts: Map<string, string>
}

const initialState: PanelState = {
  visible: false,
  loading: false,
  generation: 0,
  question: "",
  answer: "",
  error: "",
}

function supportedVersion(version: string) {
  const match = version.match(/^(\d+)\.(\d+)\.(\d+)/)
  if (!match) return false
  const major = Number(match[1])
  const minor = Number(match[2])
  const patch = Number(match[3])
  return major === 1 && (minor > 18 || (minor === 18 && patch >= 3))
}

function parseTimeout(options: Record<string, unknown> | undefined) {
  const value = options?.timeoutMs
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0) return DEFAULT_TIMEOUT_MS
  return value
}

function parse(input: string, sessionID?: string) {
  const match = input.match(/^\/btw(?:\s+([\s\S]*))?$/i)
  if (!match) return { type: "pass" as const }
  if (!sessionID) return { type: "missing" as const }
  const question = match[1]?.trim()
  if (!question) return { type: "empty" as const }
  return { type: "ask" as const, question }
}

function reconstructPrompt(info: TuiPromptInfo) {
  const unsupported = info.parts.some((part) => part.type !== "text")
  let input = info.input
  const pasted = info.parts
    .flatMap((part) => {
      if (part.type !== "text" || !part.source || !("text" in part.source)) return []
      return [{ range: part.source.text, text: part.text }]
    })
    .sort((a, b) => b.range.start - a.range.start)

  for (const part of pasted) {
    input = input.slice(0, part.range.start) + part.text + input.slice(part.range.end)
  }
  return { input, unsupported }
}

function readableError(error: unknown) {
  const object = error && typeof error === "object" ? (error as Record<string, unknown>) : undefined
  const data = object?.data && typeof object.data === "object" ? (object.data as Record<string, unknown>) : undefined
  const body = object?.body && typeof object.body === "object" ? (object.body as Record<string, unknown>) : undefined
  const bodyData = body?.data && typeof body.data === "object" ? (body.data as Record<string, unknown>) : undefined
  for (const value of [data?.message, bodyData?.message, body?.message, object?.message]) {
    if (typeof value === "string" && value.trim()) return value.trim()
  }
  if (error instanceof Error && error.message.trim()) return error.message.trim()
  return "Side question failed"
}

function questionPreview(question: string) {
  return `/btw ${question.replace(/\s+/g, " ").trim()}`
}

function Spinner(props: { color: TuiPluginApi["theme"]["current"]["info"] }) {
  const [frame, setFrame] = createSignal(0)
  const timer = setInterval(() => setFrame((value) => (value + 1) % SPINNER_FRAMES.length), 80)
  onCleanup(() => clearInterval(timer))
  return (
    <box flexDirection="row" gap={1}>
      <text fg={props.color}>{SPINNER_FRAMES[frame()]}</text>
      <text fg={props.color}>Thinking...</text>
    </box>
  )
}

function Panel(props: {
  api: TuiPluginApi
  state: PanelState
  setScroll: (scroll: ScrollBoxRenderable | undefined) => void
}) {
  const dimensions = useTerminalDimensions()
  const theme = () => props.api.theme.current
  const answerHeight = () => Math.max(3, Math.floor(dimensions().height / 3) - 5)
  const current = props.api.theme.current
  const syntaxStyle = SyntaxStyle.fromStyles({
    default: { fg: current.markdownText },
    comment: { fg: current.syntaxComment, italic: true },
    keyword: { fg: current.syntaxKeyword },
    function: { fg: current.syntaxFunction },
    variable: { fg: current.syntaxVariable },
    string: { fg: current.syntaxString },
    number: { fg: current.syntaxNumber },
    type: { fg: current.syntaxType },
    operator: { fg: current.syntaxOperator },
    punctuation: { fg: current.syntaxPunctuation },
    "markup.heading": { fg: current.markdownHeading, bold: true },
    "markup.bold": { fg: current.markdownStrong, bold: true },
    "markup.strong": { fg: current.markdownStrong, bold: true },
    "markup.italic": { fg: current.markdownEmph, italic: true },
    "markup.list": { fg: current.markdownListItem },
    "markup.quote": { fg: current.markdownBlockQuote },
    "markup.raw": { fg: current.markdownCodeBlock },
    "markup.raw.block": { fg: current.markdownCodeBlock },
    "markup.raw.inline": { fg: current.markdownCode },
    "markup.link": { fg: current.markdownLink },
    "markup.link.label": { fg: current.markdownLinkText },
    "markup.link.url": { fg: current.markdownLink },
  })
  onCleanup(() => syntaxStyle.destroy())

  return (
    <Show when={props.state.visible}>
      <box
        width="100%"
        maxHeight={answerHeight() + 5}
        flexShrink={0}
        paddingLeft={2}
        paddingRight={2}
        paddingTop={1}
        paddingBottom={1}
        backgroundColor={theme().backgroundPanel}
        borderColor={props.state.error ? theme().error : theme().info}
        border={["left", "right", "top", "bottom"]}
        flexDirection="column"
        gap={1}
      >
        <text fg={theme().textMuted} wrapMode="none" truncate={true}>
          {questionPreview(props.state.question)}
        </text>
        <Show when={props.state.loading && !props.state.answer}>
          <Spinner color={theme().info} />
        </Show>
        <Show when={props.state.error}>
          <text fg={theme().error}>{props.state.error}</text>
        </Show>
        <Show when={props.state.answer}>
          <scrollbox
            ref={props.setScroll}
            maxHeight={answerHeight()}
            stickyScroll={true}
            stickyStart="bottom"
          >
            <markdown
              content={props.state.answer}
              fg={theme().markdownText}
              bg={theme().background}
              syntaxStyle={syntaxStyle}
              conceal={true}
              streaming={true}
            />
          </scrollbox>
        </Show>
        <text fg={theme().textMuted}>
          {props.state.loading ? "esc to cancel" : "esc to dismiss | pageup/pagedown to scroll"}
        </text>
      </box>
    </Show>
  )
}

function Input(props: {
  api: TuiPluginApi
  sessionID: string
  state: PanelState
  visible?: boolean
  disabled?: boolean
  onSubmit?: () => void
  hostRef?: (ref: TuiPromptRef | undefined) => void
  setRef: (ref: TuiPromptRef | undefined) => void
  setScroll: (scroll: ScrollBoxRenderable | undefined) => void
  onLeave: (sessionID: string) => void
}) {
  const bind = (ref: TuiPromptRef | undefined) => {
    props.setRef(ref)
    props.hostRef?.(ref)
  }
  onCleanup(() => {
    bind(undefined)
    props.setScroll(undefined)
    // Slot state updates can replace this component without changing routes.
    queueMicrotask(() => props.onLeave(props.sessionID))
  })
  return (
    <box width="100%" flexDirection="column" flexShrink={0} gap={1}>
      <Panel api={props.api} state={props.state} setScroll={props.setScroll} />
      <props.api.ui.Prompt
        sessionID={props.sessionID}
        visible={props.visible}
        disabled={props.disabled}
        onSubmit={props.onSubmit}
        ref={bind}
        right={<props.api.ui.Slot name="session_prompt_right" session_id={props.sessionID} />}
      />
    </box>
  )
}

const tui: TuiPlugin = async (api, options) => {
  if (!supportedVersion(api.app.version)) {
    api.ui.toast({
      variant: "warning",
      title: "BTW plugin disabled",
      message: "Requires OpenCode >=1.18.3 and <2.0.0",
      duration: 8_000,
    })
    return
  }

  const timeoutMs = parseTimeout(options)
  const [promptRef, setPromptRef] = createSignal<TuiPromptRef>()
  const [state, setState] = createSignal<PanelState>(initialState)
  let scroll: ScrollBoxRenderable | undefined
  let active: Run | undefined
  let generation = 0
  let disposed = false
  const runs = new Set<Run>()

  const currentSession = () => {
    const route = api.route.current
    if (route.name !== "session" || !route.params || typeof route.params.sessionID !== "string") return undefined
    return route.params.sessionID
  }

  const logInternal = (stage: string) => console.error(`[${ID}] ${stage}`)
  const wait = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms))

  const deleteFork = async (sessionID: string) => {
    for (let attempt = 0; attempt < 3; attempt++) {
      try {
        await api.client.session.delete({ sessionID }, { throwOnError: true })
        return
      } catch {
        if (attempt < 2) await wait(150 * 3 ** attempt)
      }
    }
    logInternal("temporary session cleanup failed")
  }

  const cleanupFork = (run: Run, abortFirst: boolean) => {
    if (!run.forkID) return Promise.resolve()
    if (run.cleanup) return run.cleanup
    const sessionID = run.forkID
    run.cleanup = (async () => {
      if (abortFirst) {
        try {
          await api.client.session.abort({ sessionID }, { throwOnError: true })
        } catch {
          // Deletion below is authoritative; abort can race with natural completion.
        }
      }
      await deleteFork(sessionID)
    })()
    return run.cleanup
  }

  const stopRun = async (run: Run) => {
    if (!run.stopped) {
      run.stopped = true
      run.streaming = false
      run.controller.abort()
      if (run.timeout) clearTimeout(run.timeout)
      if (active === run) active = undefined
    }
    if (run.forkID) await cleanupFork(run, true)
  }

  const close = () => {
    const run = active
    setState(initialState)
    if (run) void stopRun(run)
  }

  const setStreamedAnswer = (run: Run) => {
    if (active !== run || run.stopped || !run.streaming) return
    const answer = run.partOrder.map((id) => run.parts.get(id) ?? "").join("")
    setState((current) =>
      current.generation === run.generation ? { ...current, answer } : current,
    )
  }

  const unsubscribeMessage = api.event.on("message.updated", (event) => {
    const run = active
    if (!run || run.stopped || event.properties.sessionID !== run.forkID) return
    if (event.properties.info.role === "assistant") run.assistantIDs.add(event.properties.info.id)
  })

  const unsubscribePart = api.event.on("message.part.updated", (event) => {
    const run = active
    const part = event.properties.part
    if (
      !run ||
      run.stopped ||
      !run.streaming ||
      event.properties.sessionID !== run.forkID ||
      part.type !== "text" ||
      !run.assistantIDs.has(part.messageID)
    )
      return
    if (!run.parts.has(part.id)) run.partOrder.push(part.id)
    run.parts.set(part.id, part.text)
    setStreamedAnswer(run)
  })

  const unsubscribeDelta = api.event.on("message.part.delta", (event) => {
    const run = active
    const partID = event.properties.partID
    if (
      !run ||
      run.stopped ||
      !run.streaming ||
      event.properties.sessionID !== run.forkID ||
      event.properties.field !== "text" ||
      !run.assistantIDs.has(event.properties.messageID) ||
      !run.parts.has(partID)
    )
      return
    run.parts.set(partID, (run.parts.get(partID) ?? "") + event.properties.delta)
    setStreamedAnswer(run)
  })

  const finishRun = (run: Run) => {
    if (run.timeout) clearTimeout(run.timeout)
    if (active === run) active = undefined
    runs.delete(run)
  }

  const execute = async (run: Run, question: string) => {
    try {
      const history = await api.client.session.messages(
        { sessionID: run.sourceSessionID },
        { throwOnError: true },
      )
      const messages = history.data
      let latestUser: Extract<(typeof messages)[number]["info"], { role: "user" }> | undefined
      let unfinishedAssistantID: string | undefined
      const status = api.state.session.status(run.sourceSessionID)

      for (let index = messages.length - 1; index >= 0; index--) {
        const info = messages[index].info
        if (!latestUser && info.role === "user") latestUser = info
        if (
          !unfinishedAssistantID &&
          status?.type !== "idle" &&
          info.role === "assistant" &&
          !info.time.completed &&
          !info.error
        ) {
          unfinishedAssistantID = info.id
        }
        if (latestUser && (status?.type === "idle" || unfinishedAssistantID)) break
      }

      const fork = await api.client.session.fork(
        { sessionID: run.sourceSessionID, messageID: unfinishedAssistantID },
        { throwOnError: true },
      )
      run.forkID = fork.data.id

      await api.client.session.update(
        {
          sessionID: run.forkID,
          metadata: { ...fork.data.metadata, [MARKER_KEY]: MARKER_VALUE },
          permission: [{ permission: "*", pattern: "*", action: "deny" }],
          time: { archived: Date.now() },
        },
        { throwOnError: true },
      )

      if (run.stopped || disposed) {
        await cleanupFork(run, true)
        return
      }

      run.streaming = true
      const prompt = await api.client.session.prompt(
        {
          sessionID: run.forkID,
          model: latestUser?.model
            ? { providerID: latestUser.model.providerID, modelID: latestUser.model.modelID }
            : undefined,
          agent: latestUser?.agent,
          variant: latestUser?.model.variant,
          parts: [
            {
              type: "text",
              text: `<side-question>\n${SIDE_INSTRUCTIONS}\nQuestion: ${question}\n</side-question>`,
            },
          ],
        },
        { signal: run.controller.signal, throwOnError: true },
      )
      run.streaming = false

      if (run.stopped || disposed) return
      const answer = prompt.data.parts
        .filter((part) => part.type === "text")
        .map((part) => part.text)
        .join("")
        .replace(/<think>[\s\S]*?<\/think>\s*/g, "")
        .trim()

      setState((current) =>
        current.generation === run.generation
          ? {
              ...current,
              loading: false,
              answer,
              error: answer ? "" : "No answer was returned",
            }
          : current,
      )
      await cleanupFork(run, false)
    } catch (error) {
      run.streaming = false
      if (!run.stopped && !disposed) {
        setState((current) =>
          current.generation === run.generation
            ? { ...current, loading: false, answer: "", error: readableError(error) }
            : current,
        )
        await cleanupFork(run, true)
      }
    } finally {
      finishRun(run)
    }
  }

  const ask = (sessionID: string, question: string) => {
    if (active) void stopRun(active)
    const run: Run = {
      generation: ++generation,
      sourceSessionID: sessionID,
      controller: new AbortController(),
      stopped: false,
      streaming: false,
      assistantIDs: new Set(),
      partOrder: [],
      parts: new Map(),
    }
    active = run
    runs.add(run)
    setState({
      visible: true,
      loading: true,
      sourceSessionID: sessionID,
      generation: run.generation,
      question,
      answer: "",
      error: "",
    })

    if (timeoutMs > 0) {
      run.timeout = setTimeout(() => {
        if (active !== run || run.stopped) return
        setState((current) =>
          current.generation === run.generation
            ? {
                ...current,
                loading: false,
                answer: "",
                error: `Timed out after ${Math.round(timeoutMs / 1_000)} seconds`,
              }
            : current,
        )
        void stopRun(run)
      }, timeoutMs)
    }
    void execute(run, question)
  }

  const submit = (context: { focused?: unknown }) => {
    const ref = promptRef()
    const sessionID = currentSession()
    const info = ref?.focused
      ? ref.current
      : api.route.current.name === "home" && context.focused instanceof TextareaRenderable
        ? ({ input: context.focused.plainText, parts: [] } satisfies TuiPromptInfo)
        : undefined
    if (!info) return false

    const reconstructed = reconstructPrompt(info)
    const result = parse(reconstructed.input, sessionID)
    if (result.type === "pass") return false
    if (result.type === "missing") {
      api.ui.toast({ variant: "warning", message: "Open a session before asking a side question" })
      return true
    }
    if (result.type === "empty") {
      api.ui.toast({ variant: "warning", message: "Add a question after /btw" })
      ref?.focus()
      return true
    }
    if (reconstructed.unsupported) {
      api.ui.toast({ variant: "warning", message: "/btw currently supports text only" })
      ref?.focus()
      return true
    }
    if (!ref || !sessionID) return false
    ref.reset()
    ask(sessionID, result.question)
    return true
  }

  const panelIsActive = () => {
    const current = state()
    return (
      current.visible &&
      current.sourceSessionID === currentSession() &&
      promptRef()?.focused === true &&
      !api.ui.dialog.open
    )
  }

  api.keymap.registerLayer({
    priority: 100,
    commands: [
      {
        name: command.open,
        title: "Ask a side question",
        desc: "Ask from the current context without interrupting the session",
        category: "Session",
        namespace: "palette",
        slashName: "btw",
        enabled: () => currentSession() !== undefined,
        run() {
          const ref = promptRef()
          if (!currentSession() || !ref) return false
          ref.set({ input: "/btw ", parts: [] })
          ref.focus()
          return true
        },
      },
      {
        name: command.submit,
        title: "Submit side question",
        hidden: true,
        run: submit,
      },
      {
        name: command.close,
        title: "Dismiss side question",
        hidden: true,
        run() {
          if (!panelIsActive()) return false
          close()
          return true
        },
      },
      {
        name: command.pageUp,
        title: "Scroll side question up",
        hidden: true,
        run() {
          if (!panelIsActive() || !scroll) return false
          scroll.stickyScroll = false
          scroll.scrollBy(-Math.max(1, scroll.height - 1))
          return true
        },
      },
      {
        name: command.pageDown,
        title: "Scroll side question down",
        hidden: true,
        run() {
          if (!panelIsActive() || !scroll) return false
          scroll.scrollBy(Math.max(1, scroll.height - 1))
          if (scroll.scrollTop >= Math.max(0, scroll.scrollHeight - scroll.height - 1)) {
            scroll.stickyScroll = true
          }
          return true
        },
      },
    ],
    bindings: [
      { key: "escape", cmd: command.close, desc: "Dismiss side question" },
      { key: "pageup", cmd: command.pageUp, desc: "Scroll side question up" },
      { key: "pagedown", cmd: command.pageDown, desc: "Scroll side question down" },
      ...api.tuiConfig.keybinds
        .gather(`${ID}.submit`, ["input.submit", "prompt.submit"])
        .map((binding) => ({ ...binding, cmd: command.submit, desc: "Submit side question" })),
    ],
  })

  api.slots.register({
    order: 100,
    slots: {
      session_prompt(_context, props) {
        return (
          <Input
            api={api}
            sessionID={props.session_id}
            state={state()}
            visible={props.visible}
            disabled={props.disabled}
            onSubmit={props.on_submit}
            hostRef={props.ref}
            setRef={setPromptRef}
            setScroll={(value) => (scroll = value)}
            onLeave={(sessionID) => {
              if (currentSession() !== sessionID && state().sourceSessionID === sessionID) close()
            }}
          />
        )
      },
    },
  })

  const scavenge = async () => {
    const directory = api.state.path.directory
    if (!directory) return
    const minAge = timeoutMs === 0 ? 86_400_000 : Math.max(300_000, timeoutMs + 60_000)
    let cursor: number | undefined
    for (let page = 0; page < 20; page++) {
      try {
        const result = await api.client.experimental.session.list(
          { directory, archived: true, cursor, limit: 500 },
          { throwOnError: true },
        )
        const sessions = result.data
        for (const session of sessions) {
          if (
            session.metadata?.[MARKER_KEY] === MARKER_VALUE &&
            Date.now() - session.time.created >= minAge
          ) {
            await deleteFork(session.id)
          }
        }
        if (sessions.length < 500) return
        const next = sessions.at(-1)?.time.updated
        if (!next || next === cursor) return
        cursor = next
      } catch {
        logInternal("stale session scan failed")
        return
      }
    }
  }

  void scavenge()
  api.lifecycle.onDispose(async () => {
    disposed = true
    unsubscribeMessage()
    unsubscribePart()
    unsubscribeDelta()
    setState(initialState)
    await Promise.all([...runs].map(stopRun))
  })
}

export default { id: ID, tui } satisfies TuiPluginModule
