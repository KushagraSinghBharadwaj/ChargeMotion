
import '@fontsource-variable/outfit'
import '@fontsource-variable/dm-sans'
import './style.css'
import { brandLogo, creatorMedal } from './brand.js'
import { initFx, initCardFx, initMedal, bindHeroTilt } from './fx.js'
import { open } from '@tauri-apps/plugin-dialog'
import { convertFileSrc, invoke } from '@tauri-apps/api/core'
import { listen, emitTo } from '@tauri-apps/api/event'
import {
  enable as enableAutostart,
  disable as disableAutostart,
  isEnabled as isAutostartEnabled,
} from '@tauri-apps/plugin-autostart'

const app = document.querySelector('#app')

const icons = {
  dashboard: '<svg viewBox="0 0 24 24"><rect x="3" y="3" width="8" height="8" rx="2"/><rect x="13" y="3" width="8" height="5" rx="2"/><rect x="13" y="10" width="8" height="11" rx="2"/><rect x="3" y="13" width="8" height="8" rx="2"/></svg>',
  video: '<svg viewBox="0 0 24 24"><rect x="3" y="5" width="18" height="14" rx="3"/><path d="m10 9 5 3-5 3z"/></svg>',
  settings: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="3"/><path d="m19.4 15 .1.1 1.4 1.1-1.4 2.4-1.7-.7a8 8 0 0 1-1.6.9l-.3 1.8h-2.8l-.3-1.8a8 8 0 0 1-1.6-.9l-1.7.7-1.4-2.4 1.4-1.1a8 8 0 0 1 0-1.9l-1.4-1.1 1.4-2.4 1.7.7a8 8 0 0 1 1.6-.9l.3-1.8h2.8l.3 1.8a8 8 0 0 1 1.6.9l1.7-.7 1.4 2.4-1.4 1.1a8 8 0 0 1 0 1.9z"/></svg>',
  info: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M12 11v5m0-8h.01"/></svg>',
  zap: '<svg viewBox="0 0 24 24"><path d="m13 2-3 9h7L8 22l3-9H4z"/></svg>',
  battery: '<svg viewBox="0 0 24 24"><rect x="3" y="7" width="17" height="10" rx="2"/><path d="M23 10v4M7 10v4"/></svg>',
  play: '<svg viewBox="0 0 24 24"><path d="m9 6 10 6-10 6z"/></svg>',
  folder: '<svg viewBox="0 0 24 24"><path d="M3 7a2 2 0 0 1 2-2h5l2 2h7a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/></svg>',
  arrow: '<svg viewBox="0 0 24 24"><path d="M7 17 17 7M7 7h10v10"/></svg>',
  monitor: '<svg viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="13" rx="2"/><path d="M8 21h8m-4-4v4"/></svg>',
  check: '<svg viewBox="0 0 24 24"><path d="m5 12 4 4L19 6"/></svg>',
  moon: '<svg viewBox="0 0 24 24"><path d="M20.5 14.5A8.5 8.5 0 0 1 9.5 3.5 8.5 8.5 0 1 0 20.5 14.5z"/></svg>',
  trash: '<svg viewBox="0 0 24 24"><path d="M3 6h18M8 6V4h8v2m3 0-1 14H6L5 6m4 4v6m6-6v6"/></svg>',
}

let currentPage = 'dashboard'
let selectedVideoPath = null
let selectedVideoName = null
let selectedVideoUrl = null
let errorMessage = ''
let powerStatus = null
let automaticPlaybackActive = false
let wallpaperHealth = {
  status: 'checking',
  attached: false,
  readyState: 0,
  currentTime: 0,
  paused: true,
  error: null,
}
let isFullscreenExperience = false
let startupEnabled = false
let startupBusy = false
let startupError = ''
let flashSelection = false

const VIDEO_FORMATS = ['mp4', 'webm', 'mov', 'm4v', 'avi', 'mkv']

function fileParts(path) {
  const name = path.split(/[\\/]/).pop()
  const dir = path.slice(0, path.length - name.length).replace(/[\\/]+$/, '')
  const ext = name.includes('.') ? name.split('.').pop().toUpperCase() : '—'
  return { name, dir, ext }
}

function formatDuration(seconds) {
  if (!Number.isFinite(seconds)) return '—'
  const total = Math.round(seconds)
  const h = Math.floor(total / 3600)
  const m = Math.floor((total % 3600) / 60)
  const sec = String(total % 60).padStart(2, '0')
  return h ? `${h}:${String(m).padStart(2, '0')}:${sec}` : `${m}:${sec}`
}

function icon(name) {
  return `<span class="icon">${icons[name] || ''}</span>`
}

function escapeHtml(value = '') {
  return String(value).replace(/[&<>"']/g, char => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  })[char])
}

function navItem(page, label, iconName) {
  return `
    <button class="nav-item ${currentPage === page ? 'active' : ''}" data-page="${page}">
      ${icon(iconName)}
      <span>${label}</span>
      ${currentPage === page ? '<span class="active-dot"></span>' : ''}
    </button>
  `
}

function powerLabel() {
  if (powerStatus?.on_ac_power === true) return 'External power'
  if (powerStatus?.on_ac_power === false) return 'On battery'
  return 'Checking'
}

function powerConnectionLabel() {
  if (powerStatus?.on_ac_power === true) return 'Connected'
  if (powerStatus?.on_ac_power === false) return 'Disconnected'
  return 'Unknown'
}

// Dashboard markup. Live values use data-bind / data-show and are filled in
// by patch() — the page is NOT rebuilt when power or wallpaper state changes.
function dashboardPage() {
  return `
    <div class="page-heading">
      <div>
        <div class="eyebrow">Overview</div>
        <h1>Welcome to <span class="gradient-text">ChargeMotion.</span></h1>
        <p class="page-subtitle">Your desktop experience, powered by your connection.</p>
      </div>
      <div class="date-chip">${icon('monitor')} Desktop app</div>
    </div>

    <section class="hero" id="hero">
      <div class="hero-inner">
        <div class="hero-copy">
          <div class="hero-live"><span class="status-pulse"></span><span data-bind="heroLive"></span></div>
          <h2 data-bind="headline"></h2>
          <p data-bind="subline"></p>
          <div class="hero-chips">
            <span class="chip" data-bind="chipPower"></span>
            <span class="chip" data-bind="chipBattery" data-show="hasBattery"></span>
            <span class="chip" data-bind="chipWallpaper"></span>
            <span class="chip" data-bind="chipVideo"></span>
          </div>
          <button class="primary-button" data-page="video">Open video library ${icon('arrow')}</button>
        </div>

        <div class="stage" aria-hidden="true">
          <div class="rig">
            <div class="floor"></div>
            <div class="halo"></div>
            <div class="pool"></div>

            <svg class="cable" viewBox="0 0 100 100" preserveAspectRatio="none">
              <path class="cable-base" d="M 9 72 C 22 72, 14 52, 26 52 S 20 46, 24 46"/>
              <path class="cable-flow" d="M 9 72 C 22 72, 14 52, 26 52 S 20 46, 24 46"/>
            </svg>

            <div class="plug">
              <span class="plug-icon">${icon('zap')}</span>
              <span><span data-bind="plugLabel"></span><small data-bind="plugSub"></small></span>
            </div>

            <div class="display">
              <div class="screen">
                ${selectedVideoUrl
                  ? '<video id="hero-video" muted playsinline preload="metadata" tabindex="-1"></video>'
                  : ''}
                <div class="screen-empty" ${selectedVideoUrl ? 'hidden' : ''}>
                  ${icon('play')}<span>No video selected</span>
                </div>
                <div class="screen-sheen"></div>
                <div class="screen-badge" data-bind="badge"></div>
                <div class="screen-caption" data-bind="videoName" data-show="hasVideo"></div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <div class="section-heading">
      <h3>Application overview</h3>
      <p>Your current ChargeMotion configuration.</p>
    </div>

    <div class="stats-grid">
      <article class="stat-card tilt">
        <div class="stat-top">
          <span class="stat-icon">${icon('battery')}</span>
          <span class="mini-status" data-bind="powerConnection"></span>
        </div>
        <div class="stat-label">Power status</div>
        <div class="stat-value" data-bind="powerLabel"></div>
        <div class="stat-note" data-bind="powerNote"></div>
      </article>

      <article class="stat-card tilt">
        <div class="stat-top">
          <span class="stat-icon">${icon('video')}</span>
          <span class="mini-status" data-bind="videoStatus"></span>
        </div>
        <div class="stat-label">Selected video</div>
        <div class="stat-value" data-bind="videoNameOrNone"></div>
        <div class="stat-note" data-bind="videoNote"></div>
      </article>

      <article class="stat-card tilt">
        <div class="stat-top">
          <span class="stat-icon">${icon('zap')}</span>
          <span class="mini-status" data-bind="automationStatus"></span>
        </div>
        <div class="stat-label">Automation</div>
        <div class="stat-value" data-bind="automationValue"></div>
        <div class="stat-note" data-bind="automationNote"></div>
      </article>
    </div>

    <section class="panel spot wallpaper-monitor">
      <div class="panel-heading">
        <div>
          <h3>Wallpaper health</h3>
          <p>Live checks from the desktop wallpaper engine</p>
        </div>
        <span class="coming-tag" data-bind="healthTag"></span>
      </div>
      <div class="health-grid">
        <div class="health-item"><span class="health-label">Desktop attachment</span><strong data-bind="healthAttach"></strong></div>
        <div class="health-item"><span class="health-label">Video readiness</span><strong data-bind="healthReady"></strong></div>
        <div class="health-item"><span class="health-label">Playback</span><strong data-bind="healthPlayback"></strong></div>
        <div class="health-item"><span class="health-label">Power connection</span><strong data-bind="powerConnection"></strong></div>
      </div>
      <p class="health-error" data-bind="healthError" data-show="healthError" hidden></p>
    </section>

    <section class="bottom-grid">
      <article class="panel spot automation-panel">
        <div class="panel-heading">
          <div><h3>Video configuration</h3><p>Your selected local video</p></div>
          <span class="coming-tag" data-bind="configTag"></span>
        </div>
        <div class="automation-row">
          <div class="automation-symbol">${icon('video')}</div>
          <div class="automation-copy">
            <strong data-bind="videoNameOr"></strong>
            <span data-bind="configNote"></span>
          </div>
          <button class="primary-button" data-page="video">Open</button>
        </div>
      </article>

      <article class="panel spot quick-panel">
        <div class="panel-heading"><div><h3>Quick access</h3><p>Manage your experience</p></div></div>
        <button class="quick-link" data-page="video">
          <span class="quick-icon">${icon('video')}</span>
          <span><strong>Video library</strong><small>Play or change your video</small></span>
          ${icon('arrow')}
        </button>
        <button class="quick-link" data-page="settings">
          <span class="quick-icon">${icon('settings')}</span>
          <span><strong>App settings</strong><small>Startup and application preferences</small></span>
          ${icon('arrow')}
        </button>
      </article>
    </section>
  `
}

function videoPage() {
  if (isFullscreenExperience) {
    return `
      <main class="experience-screen">
        <video
          id="video-preview"
          class="experience-video"
          controls
          autoplay
          playsinline
          preload="auto"
        ></video>
        <div class="experience-overlay">
          <span>CHARGEMOTION EXPERIENCE</span>
          <button id="exit-experience-button">Exit fullscreen · ESC</button>
        </div>
        <p id="video-error" class="video-error" ${errorMessage ? '' : 'hidden'}>${escapeHtml(errorMessage)}</p>
      </main>
    `
  }

  const flash = flashSelection
  flashSelection = false
  const file = selectedVideoPath ? fileParts(selectedVideoPath) : null

  const errorLine = `<p id="video-error" class="video-error" ${errorMessage ? '' : 'hidden'}>${escapeHtml(errorMessage)}</p>`

  const library = file
    ? `
      <div class="library-wrap">
        <section class="library ${flash ? 'just-selected' : ''}">
          <div class="player-col">
            <div class="player-frame">
              <div class="player-screen">
                <video id="video-preview" class="video-preview" controls playsinline preload="metadata"></video>
              </div>
            </div>
            <div class="player-reflection"></div>
          </div>

          <article class="panel spot library-info">
            <div class="info-top">
              <span class="mini-status" data-bind="videoStateTag"></span>
              <span class="selected-mark">${icon('check')} Selected</span>
            </div>
            <h2 class="library-title">${escapeHtml(file.name)}</h2>
            <p class="library-state" data-bind="videoStateLine"></p>

            <dl class="meta-list">
              <div><dt>Format</dt><dd>${escapeHtml(file.ext)}</dd></div>
              <div><dt>Duration</dt><dd data-meta="duration">—</dd></div>
              <div><dt>Resolution</dt><dd data-meta="resolution">—</dd></div>
              <div><dt>Location</dt><dd class="meta-path" title="${escapeHtml(file.dir)}">${escapeHtml(file.dir || '—')}</dd></div>
            </dl>

            <div class="video-actions" id="video-actions">
              <button class="primary-button" id="choose-video-button" data-tip="Pick a different video file">${icon('folder')} Choose another video</button>
              <button class="secondary-button" id="remove-request-button" data-tip="Remove the saved video">${icon('trash')} Remove</button>
              <div class="confirm-row">
                <span>Remove this video?</span>
                <button class="secondary-button confirm" id="remove-video-button">Yes, remove</button>
                <button class="ghost-button" id="cancel-remove-button">Keep it</button>
              </div>
            </div>
            ${errorLine}
          </article>
        </section>
      </div>
    `
    : `
      <section class="panel spot library-empty">
        <div class="empty-art" aria-hidden="true">
          <div class="empty-glow"></div>
          <div class="empty-display">${icon('play')}</div>
        </div>
        <h2>No video selected</h2>
        <p>Choose a video stored on this computer. ChargeMotion plays it behind your desktop whenever external power is connected.</p>
        <div class="video-actions">
          <button class="primary-button" id="choose-video-button" data-tip="Browse for a video file">${icon('folder')} Choose video</button>
        </div>
        <div class="format-row">
          <span>Supported formats</span>
          <div class="tech-list">${VIDEO_FORMATS.map(f => `<span>${f}</span>`).join('')}</div>
        </div>
        ${errorLine}
      </section>
    `

  return `
    <div class="page-heading">
      <div>
        <div class="eyebrow">Your experience</div>
        <h1>Video <span class="gradient-text">library.</span></h1>
        <p class="page-subtitle">Choose and manage your local video experience.</p>
      </div>
    </div>

    ${library}

    <div class="section-heading">
      <h3>How it works</h3>
      <p>ChargeMotion follows your power connection automatically.</p>
    </div>

    <div class="steps-grid">
      <div class="step-card tilt">
        <span>01</span>
        <strong>Select a video</strong>
        <p>Choose a supported local video file.</p>
      </div>
      <div class="step-card tilt">
        <span>02</span>
        <strong>Connect external power</strong>
        <p>ChargeMotion detects the connection and plays the video behind your desktop icons.</p>
      </div>
      <div class="step-card tilt">
        <span>03</span>
        <strong>Disconnect power</strong>
        <p>The wallpaper stops and your desktop returns to normal.</p>
      </div>
    </div>
  `
}

function startupDescription() {
  return startupEnabled
    ? 'ChargeMotion starts quietly in the system tray when you sign in to Windows.'
    : 'Start ChargeMotion automatically when you sign in to Windows.'
}

function startupStateLabel() {
  return startupBusy ? 'Updating…' : startupEnabled ? 'On' : 'Off'
}

// Updates the existing switch in place so its knob animates instead of
// being rebuilt with the page.
function updateStartupUI() {
  const toggle = document.querySelector('#startup-toggle-button')
  if (!toggle) return

  toggle.setAttribute('aria-checked', String(startupEnabled))
  toggle.setAttribute('aria-busy', String(startupBusy))
  toggle.disabled = startupBusy

  const state = document.querySelector('#startup-state')
  if (state) state.textContent = startupStateLabel()

  const desc = document.querySelector('#startup-desc')
  if (desc) desc.textContent = startupDescription()

  const error = document.querySelector('#startup-error')
  if (error) {
    error.textContent = startupError
    error.hidden = !startupError
  }
}

function settingsPage() {
  return `
    <div class="page-heading">
      <div>
        <div class="eyebrow">Preferences</div>
        <h1>App <span class="gradient-text">settings.</span></h1>
        <p class="page-subtitle">Application configuration and information.</p>
      </div>
    </div>

    <div class="settings-stack">
      <section class="panel spot settings-card">
        <header class="card-head">
          <span class="setting-icon">${icon('monitor')}</span>
          <div><h3>Startup</h3><p>How ChargeMotion launches with Windows.</p></div>
        </header>

        <div class="setting-row">
          <div class="setting-copy">
            <strong id="startup-label">Launch on startup</strong>
            <span id="startup-desc">${startupDescription()}</span>
          </div>
          <div class="switch-wrap">
            <span class="switch-state" id="startup-state">${startupStateLabel()}</span>
            <button
              type="button"
              class="switch"
              id="startup-toggle-button"
              role="switch"
              aria-checked="${startupEnabled}"
              aria-busy="${startupBusy}"
              aria-labelledby="startup-label"
              data-tip="Start ChargeMotion in the tray at sign-in"
              data-tip-pos="left"
              ${startupBusy ? 'disabled' : ''}
            ><span class="switch-knob"></span></button>
          </div>
        </div>
        <p class="video-error" id="startup-error" ${startupError ? '' : 'hidden'}>${escapeHtml(startupError)}</p>
      </section>

      <section class="panel spot settings-card">
        <header class="card-head">
          <span class="setting-icon">${icon('zap')}</span>
          <div><h3>Wallpaper automation</h3><p>Driven by your real power connection.</p></div>
        </header>

        <div class="setting-row">
          <div class="setting-copy">
            <strong>Power connection behavior</strong>
            <span>Connect power to start the wallpaper. Disconnect to stop it and restore your desktop.</span>
          </div>
          <span class="mini-status">Automatic</span>
        </div>
        <div class="setting-row">
          <div class="setting-copy"><strong>Charger</strong><span>Reported by Windows.</span></div>
          <span class="mini-status" data-bind="powerConnection"></span>
        </div>
        <div class="setting-row">
          <div class="setting-copy"><strong>Wallpaper</strong><span>Reported by the wallpaper engine.</span></div>
          <span class="mini-status" data-bind="badge"></span>
        </div>
      </section>

      <section class="panel spot settings-card">
        <header class="card-head">
          <span class="setting-icon">${icon('video')}</span>
          <div><h3>Video</h3><p>The video used for your wallpaper.</p></div>
        </header>

        <div class="setting-row">
          <div class="setting-copy">
            <strong>Saved video</strong>
            <span class="clip" data-bind="videoNameOr"></span>
          </div>
          <button class="secondary-button" data-page="video" data-tip="Open the video library" data-tip-pos="left">Manage</button>
        </div>
      </section>

      <div class="info-banner">${icon('info')} Your selected video is stored in ChargeMotion's application settings on this computer.</div>
    </div>
  `
}

function aboutPage() {
  return `
    <div class="page-heading">
      <div>
        <div class="eyebrow">THE PROJECT</div>
        <h1>About <span class="gradient-text">ChargeMotion.</span></h1>
        <p class="page-subtitle">A cinematic experience powered by your laptop's connection.</p>
      </div>
    </div>

    <section class="panel about-card tilt">
      <div class="about-logo">${brandLogo()}</div>
      <h2>ChargeMotion</h2>
      <p class="about-version">VERSION 0.1.0 · DEVELOPMENT BUILD</p>
      <p class="about-description">
        ChargeMotion is a desktop application that responds to your laptop's
        power connection and plays your selected local video experience.
      </p>
      <div class="about-divider"></div>
      <div class="tech-list">
        <span>TAURI 2</span><span>RUST</span><span>JAVASCRIPT</span><span>VITE</span>
      </div>
    </section>
  `
}

const pages = {
  dashboard: dashboardPage,
  video: videoPage,
  settings: settingsPage,
  about: aboutPage,
}

function showError(message) {
  errorMessage = message
  const element = document.querySelector('#video-error')

  if (element) {
    element.textContent = message
    element.hidden = false
  }
}

async function handlePowerStatus(status) {
  powerStatus = status
  automaticPlaybackActive = wallpaperHealth.status === 'playing'
  patch()
}

async function toggleStartup() {
  if (startupBusy) return

  startupBusy = true
  startupError = ''
  updateStartupUI()

  try {
    if (startupEnabled) {
      await disableAutostart()
      startupEnabled = false
    } else {
      await enableAutostart()
      startupEnabled = true
    }
  } catch (error) {
    console.error('Could not update startup preference:', error)
    startupError = `Could not update startup setting: ${String(error)}`
  } finally {
    startupBusy = false
    updateStartupUI()
  }
}

// ── Live-state derivation and patching ──────────────────────────────
const READY_LABELS = ['No video', 'Metadata', 'Current frame', 'More frames', 'Ready']

function derive() {
  const ac = powerStatus?.on_ac_power
  const powerState = ac === true ? 'on' : ac === false ? 'off' : 'unknown'
  const raw = wallpaperHealth.status
  const hasVideo = Boolean(selectedVideoPath)
  const battery = powerStatus?.battery_percent

  let wp
  if (raw === 'playing') wp = 'live'
  else if (raw === 'stalled') wp = 'stalled'
  else if (raw === 'error') wp = 'error'
  else if (raw === 'stopped' || (powerState === 'off' && raw === 'checking')) wp = 'standby'
  else if (raw === 'checking') wp = 'checking'
  else wp = 'starting'

  const wpLabel = { live: 'Live', stalled: 'Stalled', error: 'Error', standby: 'Standby', checking: 'Checking', starting: 'Starting' }[wp]

  let headline = 'Checking power…'
  let subline = 'Waiting for Windows to report the power connection.'
  if (wp === 'error') {
    headline = 'Wallpaper needs attention.'
    subline = wallpaperHealth.error || 'The wallpaper engine reported an error.'
  } else if (powerState === 'on') {
    if (!hasVideo) {
      headline = 'Charger connected.'
      subline = 'Select a video in your library to start the wallpaper.'
    } else if (wp === 'live') {
      headline = 'Wallpaper is live.'
      subline = `Playing ${selectedVideoName} on your desktop.`
    } else if (wp === 'stalled') {
      headline = 'Playback has stalled.'
      subline = 'The wallpaper video is not advancing.'
    } else {
      headline = 'Starting wallpaper…'
      subline = `Preparing ${selectedVideoName}.`
    }
  } else if (powerState === 'off') {
    headline = 'Running on battery.'
    subline = 'The wallpaper stays on standby until external power is connected.'
  }

  const readiness = READY_LABELS[wallpaperHealth.readyState] || 'Checking'
  const playback = { playing: 'Frames advancing', stalled: 'Not advancing', error: 'Error', stopped: 'Stopped' }[raw] || 'Checking'

  return {
    powerState,
    wp,
    hasVideo,
    hasBattery: battery != null,
    healthError: wallpaperHealth.error || '',
    heroLive: powerState === 'on' ? 'Charger connected' : powerState === 'off' ? 'On battery' : 'Checking power',
    headline,
    subline,
    chipPower: `Charger ${powerConnectionLabel().toLowerCase()}`,
    chipBattery: battery != null ? `Battery ${battery}%` : '',
    chipWallpaper: `Wallpaper ${wpLabel.toLowerCase()}`,
    chipVideo: selectedVideoName || 'No video',
    plugLabel: powerState === 'on' ? 'External power' : powerState === 'off' ? 'Battery' : 'Power',
    plugSub: battery != null ? `${battery}%` : powerConnectionLabel(),
    badge: wpLabel,
    videoName: selectedVideoName || '',
    videoNameOrNone: selectedVideoName || 'No video',
    videoNameOr: selectedVideoName || 'No video selected',
    powerConnection: powerConnectionLabel(),
    powerLabel: powerLabel(),
    powerNote: battery != null ? `Battery level: ${battery}%` : 'Live Windows power monitoring',
    videoStatus: hasVideo ? 'Selected' : 'Not selected',
    videoNote: hasVideo ? 'Saved on this computer' : 'Choose a video in your library',
    automationStatus: automaticPlaybackActive ? 'Playing' : 'Standby',
    automationValue: automaticPlaybackActive ? 'Playing' : 'Waiting',
    automationNote: automaticPlaybackActive
      ? 'Wallpaper video is confirmed playing'
      : raw === 'error'
        ? 'Wallpaper error: check the health panel below'
        : 'Waiting for confirmed wallpaper playback',
    healthTag: raw.toUpperCase(),
    healthAttach: wallpaperHealth.attached ? 'Confirmed' : 'Not attached',
    healthReady: readiness,
    healthPlayback: playback,
    configTag: 'Ready',
    configNote: hasVideo ? 'Ready for playback' : 'Select a video to get started',
    videoStateTag: !hasVideo ? 'No video' : wp === 'live' ? 'Live wallpaper' : wp === 'error' ? 'Needs attention' : powerState === 'on' ? 'Starting' : powerState === 'off' ? 'Standby' : 'Ready',
    videoStateLine: !hasVideo
      ? ''
      : wp === 'live' ? 'Currently playing as your desktop wallpaper.'
      : wp === 'error' ? 'The wallpaper reported an error. See the dashboard health panel.'
      : wp === 'stalled' ? 'Wallpaper playback has stalled.'
      : powerState === 'on' ? 'Starting the wallpaper…'
      : powerState === 'off' ? 'Waiting for external power to start the wallpaper.'
      : 'Checking the power connection…',
    crumb: currentPage.charAt(0).toUpperCase() + currentPage.slice(1),
  }
}

// Updates text/state in place. Never rebuilds DOM, so hover, tilt and
// animations are unaffected by the once-per-second health events.
function patch() {
  const d = derive()
  const root = document.documentElement
  root.dataset.power = d.powerState
  root.dataset.wp = d.wp
  root.dataset.video = d.hasVideo ? 'yes' : 'no'

  document.querySelectorAll('[data-bind]').forEach(el => {
    const value = d[el.dataset.bind]
    if (value !== undefined && el.textContent !== value) el.textContent = value
  })
  document.querySelectorAll('[data-show]').forEach(el => {
    el.hidden = !d[el.dataset.show]
  })
}

// Shows one real, paused frame of the selected video inside the hero display.
// It is never played, so it adds no decoding load next to the wallpaper.
function syncHeroVideo() {
  const el = document.querySelector('#hero-video')
  if (!el || !selectedVideoUrl) return

  el.muted = true
  el.addEventListener('loadedmetadata', () => {
    try {
      el.currentTime = Math.min(1, (el.duration || 2) / 2)
    } catch (error) {
      console.warn('Could not seek hero preview:', error)
    }
  }, { once: true })
  el.addEventListener('seeked', () => el.classList.add('ready'), { once: true })
  el.addEventListener('error', () => {
    const empty = document.querySelector('.screen-empty')
    if (empty) {
      empty.hidden = false
      empty.querySelector('span').textContent = 'Preview unavailable'
    }
  }, { once: true })
  el.src = selectedVideoUrl
}

// ── Rendering: build the shell once, swap only the page ────────────
let lastRenderedPage = null

function ensureShell() {
  if (document.querySelector('.app-shell')) return

  app.innerHTML = `
    <div class="app-shell">
      <aside class="sidebar">
        <div class="brand">
          ${brandLogo()}
          <div class="brand-name">Charge<span>Motion</span><small>Desktop experience</small></div>
        </div>

        <div class="nav-caption">Workspace</div>
        <nav class="navigation">
          ${navItem('dashboard', 'Dashboard', 'dashboard')}
          ${navItem('video', 'Video library', 'video')}
        </nav>

        <div class="nav-caption preferences-caption">Preferences</div>
        <nav class="navigation">
          ${navItem('settings', 'Settings', 'settings')}
          ${navItem('about', 'About', 'info')}
        </nav>

        <div class="sidebar-bottom">
          <div class="sidebar-status"><span class="status-pulse"></span><span>Application running</span></div>
          <div class="sidebar-version">ChargeMotion v0.1.0</div>
        </div>
      </aside>

      <main class="main-area">
        <header class="topbar">
          <div class="breadcrumb">ChargeMotion <span>/</span> <b data-bind="crumb" style="font-weight:500"></b></div>
          <div class="topbar-right"><span class="build-indicator"></span> Development build</div>
        </header>
        <div class="page-content" id="page-content"></div>
      </main>
    </div>
  `
}

function updateNav() {
  document.querySelectorAll('.nav-item').forEach(button => {
    button.classList.toggle('active', button.dataset.page === currentPage)
  })
}

function renderPage() {
  const slot = document.querySelector('#page-content')
  if (!slot) return

  slot.innerHTML = `
    <div class="page page-${currentPage}">
      <div class="page-body">${pages[currentPage]()}</div>
      <footer class="footer">
        <span>ChargeMotion</span>
        ${creatorMedal()}
        <span>Built for a better desktop experience.</span>
      </footer>
    </div>
  `
  if (lastRenderedPage !== currentPage) slot.scrollTop = 0
  lastRenderedPage = currentPage

  updateNav()
  bindPage()
  syncHeroVideo()
  bindHeroTilt(document.querySelector('#hero'))
  patch()
}

function render() {
  if (isFullscreenExperience && currentPage === 'video') {
    app.innerHTML = pages.video()
    lastRenderedPage = null
    bindPage()
    return
  }

  ensureShell()
  renderPage()
}

// Navigation is delegated once, so re-rendering a page never stacks listeners.
// The outgoing page fades out briefly (skipped for reduced motion, hidden
// windows and the static fx tier), then the new page renders and animates in.
let navToken = 0

function canAnimate() {
  const root = document.documentElement
  return (
    !window.matchMedia('(prefers-reduced-motion: reduce)').matches &&
    root.dataset.fx !== 'static' &&
    root.dataset.active !== 'false'
  )
}

app.addEventListener('click', event => {
  const target = event.target.closest('[data-page]')
  if (!target) return

  const next = target.dataset.page
  if (next === currentPage && document.querySelector('.app-shell')) return

  const token = ++navToken
  const commit = () => {
    if (token === navToken) render()
  }

  currentPage = next
  errorMessage = ''
  updateNav()

  const outgoing = document.querySelector('.page')
  if (outgoing && canAnimate()) {
    outgoing
      .animate(
        [
          { opacity: 1, transform: 'none' },
          { opacity: 0, transform: 'translateY(-8px) scale(0.994)' },
        ],
        { duration: 130, easing: 'ease-in', fill: 'forwards' }
      )
      .finished.then(commit, commit)
  } else {
    commit()
  }
})

// Per-page bindings (video, choose/remove buttons, startup toggle).
function bindPage() {
  const video = document.querySelector('#video-preview')

  if (video && selectedVideoUrl) {
    video.src = selectedVideoUrl
    video.addEventListener('error', () => {
      showError('This video could not be played. Check that the file still exists and uses a supported format.')
    })
    video.addEventListener('loadedmetadata', () => {
      const duration = document.querySelector('[data-meta="duration"]')
      const resolution = document.querySelector('[data-meta="resolution"]')
      if (duration) duration.textContent = formatDuration(video.duration)
      if (resolution) {
        resolution.textContent = video.videoWidth ? `${video.videoWidth} × ${video.videoHeight}` : '—'
      }
    }, { once: true })
  }

  const actions = document.querySelector('#video-actions')
  const requestRemove = document.querySelector('#remove-request-button')
  const cancelRemove = document.querySelector('#cancel-remove-button')
  if (actions && requestRemove && cancelRemove) {
    requestRemove.addEventListener('click', () => {
      actions.classList.add('confirming')
      document.querySelector('#remove-video-button')?.focus()
    })
    cancelRemove.addEventListener('click', () => {
      actions.classList.remove('confirming')
      requestRemove.focus()
    })
  }

  const chooseButton = document.querySelector('#choose-video-button')

  if (chooseButton) {
    chooseButton.addEventListener('click', async () => {
      try {
        errorMessage = ''

        const path = await open({
          title: 'Choose a video for ChargeMotion',
          multiple: false,
          filters: [{
            name: 'Video files',
            extensions: ['mp4', 'webm', 'mov', 'm4v', 'avi', 'mkv'],
          }],
        })

        if (!path) return

        await invoke('save_selected_video', { path })

        selectedVideoPath = path
        selectedVideoName = path.split(/[\\/]/).pop()
        selectedVideoUrl = convertFileSrc(path)

        flashSelection = true
        render()

        await emitTo('wallpaper', 'video-selection-changed', { path })

        automaticPlaybackActive = wallpaperHealth.status === 'playing'
        patch()
      } catch (error) {
        console.error(error)
        showError(`Could not load the selected video: ${String(error)}`)
      }
    })
  }

  const removeButton = document.querySelector('#remove-video-button')

  if (removeButton) {
    removeButton.addEventListener('click', async () => {
      try {
        await invoke('clear_selected_video')

        const player = document.querySelector('#video-preview')
        if (player) player.pause()

        await emitTo('wallpaper', 'video-selection-changed', { path: null })
        automaticPlaybackActive = false

        selectedVideoPath = null
        selectedVideoName = null
        selectedVideoUrl = null
        errorMessage = ''
        currentPage = 'video'
        render()
      } catch (error) {
        console.error(error)
        showError(`Could not remove the saved video: ${String(error)}`)
      }
    })
  }

  const startupButton = document.querySelector('#startup-toggle-button')
  if (startupButton) {
    startupButton.addEventListener('click', () => {
      void toggleStartup()
    })
  }
}

async function initialize() {
  try {
    const savedPath = await invoke('get_selected_video')

    if (savedPath) {
      selectedVideoPath = savedPath
      selectedVideoName = savedPath.split(/[\\/]/).pop()
      selectedVideoUrl = convertFileSrc(savedPath)
    }
  } catch (error) {
    console.error('Could not restore saved video:', error)
  }

  try {
    startupEnabled = await isAutostartEnabled()
  } catch (error) {
    console.error('Could not read startup setting:', error)
    startupError = 'Startup settings are not available. Check the Tauri autostart plugin setup.'
  }

  try {
    await listen('power-status-changed', event => {
      void handlePowerStatus(event.payload)
    })
  } catch (error) {
    console.error('Could not register power listener:', error)
  }

render()

  try {
    await listen('wallpaper-health-changed', event => {
      wallpaperHealth = {
        ...wallpaperHealth,
        ...event.payload,
      }

      automaticPlaybackActive = wallpaperHealth.status === 'playing'
      patch()
    })
  } catch (error) {
    console.error('Could not register wallpaper health listener:', error)
  }

  try {
    const status = await invoke('get_power_status')
    await handlePowerStatus(status)
  } catch (error) {
    console.error('Could not retrieve initial power status:', error)
    powerStatus = null
    patch()
  }
}

initFx()
initCardFx(app)
initMedal()
void initialize()
