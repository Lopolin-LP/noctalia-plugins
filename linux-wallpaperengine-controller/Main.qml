import QtQuick
import Quickshell
import Quickshell.Io

import qs.Commons
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null

  property bool checkingEngine: true
  property bool engineAvailable: false
  property bool isApplying: false
  property bool stopRequested: false
  property string lastError: ""
  property string statusMessage: ""
  property string autoDetectedWallpapersFolder: ""

  property var pendingCommand: []

  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  Component.onCompleted: {
    Logger.i("LWEController", "Main initialized");
  }

  function ensureSettingsRoot() {
    if (!pluginApi) {
      return;
    }

    if (pluginApi.pluginSettings.screens === undefined || pluginApi.pluginSettings.screens === null) {
      pluginApi.pluginSettings.screens = {};
    }
  }

  function defaultScaling() {
    return cfg.defaultScaling ?? defaults.defaultScaling ?? "fill";
  }

  function defaultFps() {
    return cfg.defaultFps ?? defaults.defaultFps ?? 30;
  }

  function defaultVolume() {
    const value = Number(cfg.defaultVolume ?? defaults.defaultVolume ?? 100);
    if (isNaN(value)) {
      return 100;
    }
    return Math.max(0, Math.min(100, Math.floor(value)));
  }

  function defaultMuted() {
    return cfg.defaultMuted ?? defaults.defaultMuted ?? true;
  }

  function defaultAudioReactiveEffects() {
    return cfg.defaultAudioReactiveEffects ?? defaults.defaultAudioReactiveEffects ?? true;
  }

  function defaultDisableMouse() {
    return cfg.defaultDisableMouse ?? defaults.defaultDisableMouse ?? false;
  }

  function defaultDisableParallax() {
    return cfg.defaultDisableParallax ?? defaults.defaultDisableParallax ?? false;
  }

  function defaultNoFullscreenPause() {
    return cfg.defaultNoFullscreenPause ?? defaults.defaultNoFullscreenPause ?? false;
  }

  function defaultFullscreenPauseOnlyActive() {
    return cfg.defaultFullscreenPauseOnlyActive ?? defaults.defaultFullscreenPauseOnlyActive ?? false;
  }

  function defaultAutoApply() {
    return cfg.autoApplyOnStartup ?? defaults.autoApplyOnStartup ?? true;
  }

  function defaultAutoDetectWorkshop() {
    return cfg.autoDetectWorkshop ?? defaults.autoDetectWorkshop ?? true;
  }

  function assetsDir() {
    return cfg.assetsDir ?? defaults.assetsDir ?? "";
  }

  function shouldRunWorkshopScan() {
    if (!defaultAutoDetectWorkshop()) {
      return false;
    }

    const configuredFolder = normalizedPath(cfg.wallpapersFolder ?? defaults.wallpapersFolder ?? "");
    return configuredFolder.length === 0;
  }

  function normalizedPath(path) {
    return Settings.preprocessPath(String(path || ""));
  }

  function getScreenConfig(screenName) {
    const screenConfigs = cfg.screens || ({});
    const raw = screenConfigs[screenName] || ({});

    const resolvedVolume = Number(raw.volume ?? defaultVolume());

    return {
      path: raw.path ?? "",
      scaling: raw.scaling ?? defaultScaling(),
      volume: isNaN(resolvedVolume) ? defaultVolume() : Math.max(0, Math.min(100, Math.floor(resolvedVolume))),
      muted: raw.muted ?? defaultMuted(),
      audioReactiveEffects: raw.audioReactiveEffects ?? defaultAudioReactiveEffects(),
      disableMouse: raw.disableMouse ?? defaultDisableMouse(),
      disableParallax: raw.disableParallax ?? defaultDisableParallax()
    };
  }

  function hasAnyConfiguredWallpaper() {
    for (const screen of Quickshell.screens) {
      const screenCfg = getScreenConfig(screen.name);
      if (screenCfg.path && screenCfg.path.length > 0) {
        return true;
      }
    }
    return false;
  }

  function setScreenWallpaper(screenName, path) {
    setScreenWallpaperWithOptions(screenName, path, ({}));
  }

  function setScreenWallpaperWithOptions(screenName, path, options) {
    if (!pluginApi) {
      return;
    }

    Logger.i("LWEController", "Set wallpaper requested", screenName, path, JSON.stringify(options || ({})));

    ensureSettingsRoot();

    if (pluginApi.pluginSettings.screens[screenName] === undefined) {
      pluginApi.pluginSettings.screens[screenName] = {};
    }

    pluginApi.pluginSettings.screens[screenName].path = path;

    const resolvedScaling = String(options?.scaling || "").trim();
    if (resolvedScaling.length > 0) {
      pluginApi.pluginSettings.screens[screenName].scaling = resolvedScaling;
    }

    if (options?.volume !== undefined) {
      const rawVolume = Number(options.volume);
      if (!isNaN(rawVolume)) {
        pluginApi.pluginSettings.screens[screenName].volume = Math.max(0, Math.min(100, Math.floor(rawVolume)));
      }
    }

    if (options?.muted !== undefined) {
      pluginApi.pluginSettings.screens[screenName].muted = !!options.muted;
    }

    if (options?.audioReactiveEffects !== undefined) {
      pluginApi.pluginSettings.screens[screenName].audioReactiveEffects = !!options.audioReactiveEffects;
    }

    if (options?.disableMouse !== undefined) {
      pluginApi.pluginSettings.screens[screenName].disableMouse = !!options.disableMouse;
    }

    if (options?.disableParallax !== undefined) {
      pluginApi.pluginSettings.screens[screenName].disableParallax = !!options.disableParallax;
    }

    pluginApi.saveSettings();

    restartEngine();
  }

  function clearScreenWallpaper(screenName) {
    if (!pluginApi) {
      return;
    }

    Logger.i("LWEController", "Clear wallpaper requested", screenName);

    ensureSettingsRoot();

    if (pluginApi.pluginSettings.screens[screenName] === undefined) {
      pluginApi.pluginSettings.screens[screenName] = {};
    }

    pluginApi.pluginSettings.screens[screenName].path = "";
    pluginApi.saveSettings();

    restartEngine();
  }

  function setAllScreensWallpaper(path) {
    setAllScreensWallpaperWithOptions(path, ({}));
  }

  function setAllScreensWallpaperWithOptions(path, options) {
    if (!pluginApi || !path || String(path).length === 0) {
      return;
    }

    Logger.i("LWEController", "Set wallpaper for all screens", path, JSON.stringify(options || ({})));

    ensureSettingsRoot();

    const resolvedScaling = String(options?.scaling || "").trim();
    const resolvedVolumeRaw = Number(options?.volume);
    const hasResolvedVolume = !isNaN(resolvedVolumeRaw);
    const resolvedVolume = hasResolvedVolume ? Math.max(0, Math.min(100, Math.floor(resolvedVolumeRaw))) : 0;
    const hasMuted = options?.muted !== undefined;
    const hasAudioReactive = options?.audioReactiveEffects !== undefined;
    const hasDisableMouse = options?.disableMouse !== undefined;
    const hasDisableParallax = options?.disableParallax !== undefined;

    for (const screen of Quickshell.screens) {
      if (pluginApi.pluginSettings.screens[screen.name] === undefined) {
        pluginApi.pluginSettings.screens[screen.name] = {};
      }

      pluginApi.pluginSettings.screens[screen.name].path = path;
      if (resolvedScaling.length > 0) {
        pluginApi.pluginSettings.screens[screen.name].scaling = resolvedScaling;
      }
      if (hasResolvedVolume) {
        pluginApi.pluginSettings.screens[screen.name].volume = resolvedVolume;
      }
      if (hasMuted) {
        pluginApi.pluginSettings.screens[screen.name].muted = !!options.muted;
      }
      if (hasAudioReactive) {
        pluginApi.pluginSettings.screens[screen.name].audioReactiveEffects = !!options.audioReactiveEffects;
      }
      if (hasDisableMouse) {
        pluginApi.pluginSettings.screens[screen.name].disableMouse = !!options.disableMouse;
      }
      if (hasDisableParallax) {
        pluginApi.pluginSettings.screens[screen.name].disableParallax = !!options.disableParallax;
      }
    }

    pluginApi.saveSettings();
    restartEngine();
  }

  function extractRuntimeError(stderrText) {
    const text = String(stderrText || "").trim();
    if (text.length === 0) {
      return "";
    }

    const lower = text.toLowerCase();

    if (lower.indexOf("cannot find a valid assets folder") !== -1) {
      return pluginApi?.tr("main.error.assetsMissing");
    }

    if (lower.indexOf("at least one background id must be specified") !== -1) {
      return pluginApi?.tr("main.error.noBackground");
    }

    if (lower.indexOf("opengl") !== -1 || lower.indexOf("glfw") !== -1) {
      return pluginApi?.tr("main.error.opengl");
    }

    return text;
  }

  function buildCommand() {
    const command = ["linux-wallpaperengine"];
    let firstPath = "";
    let runtimeOptions = {
      volume: defaultVolume(),
      muted: defaultMuted(),
      audioReactiveEffects: defaultAudioReactiveEffects(),
      disableMouse: defaultDisableMouse(),
      disableParallax: defaultDisableParallax()
    };

    for (const candidate of Quickshell.screens) {
      const candidateCfg = getScreenConfig(candidate.name);
      const candidatePath = normalizedPath(candidateCfg.path);
      if (candidatePath && candidatePath.length > 0) {
        runtimeOptions = {
          volume: candidateCfg.volume,
          muted: candidateCfg.muted,
          audioReactiveEffects: candidateCfg.audioReactiveEffects,
          disableMouse: candidateCfg.disableMouse,
          disableParallax: candidateCfg.disableParallax
        };
        break;
      }
    }

    command.push("--fps");
    command.push(String(defaultFps()));

    if (runtimeOptions.muted) {
      command.push("--silent");
    } else {
      command.push("--volume");
      command.push(String(runtimeOptions.volume));
    }

    if (!runtimeOptions.audioReactiveEffects) {
      command.push("--no-audio-processing");
    }

    if (runtimeOptions.disableMouse) {
      command.push("--disable-mouse");
    }

    if (runtimeOptions.disableParallax) {
      command.push("--disable-parallax");
    }

    if (defaultNoFullscreenPause()) {
      command.push("--no-fullscreen-pause");
    }

    if (defaultFullscreenPauseOnlyActive()) {
      command.push("--fullscreen-pause-only-active");
    }

    const maybeAssetsDir = normalizedPath(assetsDir());
    if (maybeAssetsDir.length > 0) {
      command.push("--assets-dir");
      command.push(maybeAssetsDir);
    }

    for (const screen of Quickshell.screens) {
      const screenCfg = getScreenConfig(screen.name);
      const path = normalizedPath(screenCfg.path);
      if (!path || path.length === 0) {
        continue;
      }

      if (firstPath.length === 0) {
        firstPath = path;
      }

      command.push("--scaling");
      command.push(String(screenCfg.scaling));
      command.push("--screen-root");
      command.push(screen.name);
      command.push("--bg");
      command.push(path);
    }

    if (firstPath.length > 0) {
      command.push(firstPath);
    }

    return command;
  }

  function stopAll() {
    Logger.i("LWEController", "Stopping engine process");
    pendingCommand = [];

    if (engineProcess.running) {
      stopRequested = true;
      engineProcess.running = false;
    }

    isApplying = false;
    statusMessage = pluginApi?.tr("main.status.stopped");
  }

  function startEngineWithCommand(command) {
    if (!engineAvailable) {
      Logger.w("LWEController", "Skip start: engine unavailable");
      return;
    }

    if (!command || command.length <= 1) {
      Logger.w("LWEController", "Skip start: empty command");
      stopAll();
      return;
    }

    Logger.d("LWEController", "Starting engine command", JSON.stringify(command));

    lastError = "";
    statusMessage = pluginApi?.tr("main.status.starting");
    isApplying = true;

    engineProcess.command = command;
    engineProcess.running = true;
  }

  function restartEngine() {
    if (!engineAvailable) {
      Logger.w("LWEController", "Skip restart: engine unavailable");
      return;
    }

    const command = buildCommand();
    if (!command || command.length <= 1) {
      Logger.w("LWEController", "Restart resolved to empty command; stopping engine");
      stopAll();
      return;
    }

    if (engineProcess.running) {
      Logger.d("LWEController", "Engine already running; queue restart command");
      pendingCommand = command;
      stopRequested = true;
      engineProcess.running = false;
      return;
    }

    startEngineWithCommand(command);
  }

  function reload() {
    if (!hasAnyConfiguredWallpaper()) {
      lastError = "";
      statusMessage = pluginApi?.tr("main.status.ready");
      Logger.i("LWEController", "Reload skipped: no configured wallpaper paths");
      return;
    }

    restartEngine();
  }

  Process {
    id: workshopScan
    running: root.shouldRunWorkshopScan()
    command: [
      "sh",
      "-c",
      "for common in \"$HOME/.steam/steam/steamapps/common\" \"$HOME/.local/share/Steam/steamapps/common\" \"$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/common\" \"$HOME/snap/steam/common/.local/share/Steam/steamapps/common\"; do if [ -d \"$common\" ]; then workshop=\"${common%/common}/workshop/content/431960\"; if [ -d \"$workshop\" ]; then printf '%s\\n' \"$workshop\"; exit 0; fi; fi; done; exit 0"
    ]

    onExited: function () {
      const detected = String(stdout.text || "").trim();
      root.autoDetectedWallpapersFolder = detected;

      if (detected.length > 0) {
        Logger.i("LWEController", "Detected workshop folder", detected);
      } else {
        Logger.w("LWEController", "No workshop folder detected from Steam candidates");
      }

      if (!root.pluginApi || detected.length === 0) {
        return;
      }

      const resolvedConfigured = root.normalizedPath(root.cfg.wallpapersFolder ?? root.defaults.wallpapersFolder ?? "");
      if (resolvedConfigured.length === 0 && root.defaultAutoDetectWorkshop()) {
        Logger.i("LWEController", "Auto-applying detected wallpapersFolder", detected);
        root.pluginApi.pluginSettings.wallpapersFolder = detected;
        root.pluginApi.saveSettings();
      }
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  Process {
    id: engineCheck
    running: true
    command: ["sh", "-c", "command -v linux-wallpaperengine >/dev/null 2>&1"]

    onExited: function (exitCode) {
      root.engineAvailable = (exitCode === 0);
      root.checkingEngine = false;

      Logger.i("LWEController", "Engine check finished", "exitCode=", exitCode, "available=", root.engineAvailable);

      if (!root.engineAvailable) {
        root.lastError = root.pluginApi?.tr("main.error.notInstalled");
        root.statusMessage = root.pluginApi?.tr("main.status.unavailable");
        Logger.e("LWEController", "linux-wallpaperengine binary not found in PATH");
        return;
      }

      root.statusMessage = root.pluginApi?.tr("main.status.ready");

      if (root.defaultAutoApply() && root.hasAnyConfiguredWallpaper()) {
        Logger.i("LWEController", "Auto apply enabled with configured wallpapers; restarting engine");
        root.restartEngine();
      }
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  Process {
    id: engineProcess

    onExited: function (exitCode, exitStatus) {
      root.isApplying = false;

      Logger.i("LWEController", "Engine process exited", "exitCode=", exitCode, "exitStatus=", exitStatus, "stopRequested=", root.stopRequested);

      if (root.stopRequested) {
        root.stopRequested = false;

        if (root.pendingCommand.length > 0) {
          const nextCommand = root.pendingCommand;
          root.pendingCommand = [];
          Logger.d("LWEController", "Applying pending command after stop");
          root.startEngineWithCommand(nextCommand);
          return;
        }

        root.statusMessage = root.pluginApi?.tr("main.status.stopped");
        return;
      }

      if (exitCode !== 0 || exitStatus !== Process.NormalExit) {
        const parsed = root.extractRuntimeError(stderr.text);
        if (parsed.length > 0) {
          root.lastError = parsed;
          Logger.e("LWEController", "Engine runtime error", parsed);
        }
        root.statusMessage = root.pluginApi?.tr("main.status.crashed");
      } else {
        root.statusMessage = root.pluginApi?.tr("main.status.stopped");
      }
    }

    stdout: StdioCollector {}

    stderr: StdioCollector {
      onStreamFinished: {
        if (root.stopRequested) {
          return;
        }

        const parsed = root.extractRuntimeError(text);
        if (parsed.length > 0) {
          root.lastError = parsed;
          Logger.w("LWEController", "Engine stderr", parsed);
        }
      }
    }
  }

  IpcHandler {
    target: "plugin:linux-wallpaperengine-controller"

    function toggle() {
      if (root.pluginApi) {
        root.pluginApi.withCurrentScreen(screen => {
          root.pluginApi.togglePanel(screen);
        });
      }
    }

    function apply(screenName, bgPath) {
      if (!screenName || !bgPath) {
        Logger.w("LWEController", "IPC apply ignored due to invalid args", screenName, bgPath);
        return;
      }

      Logger.i("LWEController", "IPC apply", screenName, bgPath);

      root.setScreenWallpaper(screenName, bgPath);
    }

    function stop(screenName) {
      if (!screenName || screenName === "all") {
        Logger.i("LWEController", "IPC stop all");
        root.stopAll();
        return;
      }

      Logger.i("LWEController", "IPC stop screen", screenName);

      root.clearScreenWallpaper(screenName);
    }

    function reload() {
      root.reload();
    }
  }
}
