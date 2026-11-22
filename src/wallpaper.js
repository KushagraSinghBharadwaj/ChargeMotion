import './wallpaper.css'
import { attachConsole } from '@tauri-apps/plugin-log'
import { convertFileSrc, invoke } from '@tauri-apps/api/core'
import { listen, emitTo } from '@tauri-apps/api/event'
import { getCurrentWindow, primaryMonitor } from '@tauri-apps/api/window'
import {
  attach,
  detach,
  capabilities,
  isAttached,
} from 'tauri-plugin-wallpaper'

const wallpaperWindow = getCurrentWindow()
const video = document.querySelector('#wallpaper-video')

let active = false
let currentVideoPath = null
let currentPowerStatus = null
let lastObservedTime = 0
let lastProgressAt = Date.now()

async function publishHealth(status, error = null, skipAttachmentCheck = false) {
  let attached = false

  if (!skipAttachmentCheck) {
    try {
      attached = await isAttached('wallpaper')
    } catch (checkError) {
      console.warn('Could not check wallpaper attachment:', checkError)
    }
  }

  const payload = {
    status,
    attached,
    readyState: video.readyState,
    currentTime: video.currentTime,
    paused: video.paused,
    error: error ? String(error) : null,
  }

  try {
    await emitTo('main', 'wallpaper-health-changed', payload)
  } catch (eventError) {
    console.warn('Could not send wallpaper health to dashboard:', eventError)
  }
}

async function inspectPlayback() {
  if (!active) return

  const currentTime = video.currentTime
  const now = Date.now()

  if (!video.paused && currentTime > lastObservedTime + 0.01) {
    lastProgressAt = now
  }

  lastObservedTime = currentTime

  let status = 'loading'

  if (video.error) {
    status = 'error'
  } else if (!video.paused && video.readyState >= 2 && now - lastProgressAt < 3000) {
    status = 'playing'
  } else if (!video.paused && video.readyState >= 2 && now - lastProgressAt >= 3000) {
    status = 'stalled'
  }

  await publishHealth(
    status,
    video.error ? `Video playback error (code ${video.error.code})` : null
  )
}
async function startWallpaper(path) {
  if (!path) return

  try {
    lastObservedTime = 0
    lastProgressAt = Date.now()

    await publishHealth('loading')
    console.log('ChargeMotion: Starting wallpaper:', path)

    await publishHealth('stage-capabilities', null, true)
    const support = await capabilities()

    console.log('Wallpaper capabilities:', support)

    if (!support.attach) {
      throw new Error('Desktop wallpaper attachment is not supported.')
    }

    await publishHealth('stage-attachment-check', null, true)
    const alreadyAttached = await isAttached('wallpaper')

    if (alreadyAttached && currentVideoPath === path) {
      active = true
      await publishHealth('loading')
      return
    }

    if (alreadyAttached) {
      currentVideoPath = path
      video.src = convertFileSrc(path)
      video.load()
      await video.play()

      active = true
      lastObservedTime = 0
      lastProgressAt = Date.now()
      await publishHealth('loading')
      console.log('ChargeMotion: Wallpaper video updated.')
      return
    }

    currentVideoPath = path
    video.src = convertFileSrc(path)
    video.load()

    await publishHealth('stage-monitor-check', null, true)
    const monitor = await primaryMonitor()

    const attachOptions = {
      windowLabel: 'wallpaper',
    }

    if (monitor?.name) {
      attachOptions.monitor = monitor.name
      console.log('ChargeMotion: Using monitor:', monitor.name)
    } else {
      console.warn('ChargeMotion: Monitor name unavailable.')
    }

    await publishHealth('stage-native-attach', null, true)
    await attach(attachOptions)

    await publishHealth('stage-verify-attach', null, true)
    const attached = await isAttached('wallpaper')

    console.log('ChargeMotion: Attachment verification:', attached)

    if (!attached) {
      throw new Error('Windows did not confirm wallpaper attachment.')
    }

    await publishHealth('stage-show-window', null, true)
    await wallpaperWindow.show()

    await publishHealth('stage-video-play', null, true)
    await video.play()

    if (video.paused) {
      throw new Error('Wallpaper video did not start playing.')
    }

    active = true
    lastObservedTime = 0
    lastProgressAt = Date.now()

    await publishHealth('loading')
    console.log('ChargeMotion: Wallpaper successfully attached and playing.')
  } catch (error) {
    console.error('Could not start desktop wallpaper:', error)

    active = false
    currentVideoPath = null

    await publishHealth('error', error?.message || String(error), true)

    try {
      if (await isAttached('wallpaper')) {
        await detach('wallpaper')
      }
    } catch (cleanupError) {
      console.error('Wallpaper cleanup failed:', cleanupError)
    }

    await wallpaperWindow.hide()
  }
}
async function stopWallpaper() {
  try {
    video.pause()
    video.removeAttribute('src')
    video.load()

    const attached = await isAttached('wallpaper')

    if (attached) {
      await detach('wallpaper')
    }

    await wallpaperWindow.hide()

    active = false
    currentVideoPath = null

    await publishHealth('stopped')
    console.log('ChargeMotion: Wallpaper stopped.')
  } catch (error) {
    console.error('Could not stop desktop wallpaper:', error)
  }
}

async function initializeWallpaper() {
  await listen('power-status-changed', async (event) => {
    currentPowerStatus = event.payload

    if (currentPowerStatus?.on_ac_power === true) {
      const path = await invoke('get_selected_video')

      if (path) {
        await startWallpaper(path)
      } else {
        await stopWallpaper()
      }
    } else if (currentPowerStatus?.on_ac_power === false) {
      await stopWallpaper()
    }
  })

  await listen('video-selection-changed', async (event) => {
    const path = event.payload?.path

    if (path && currentPowerStatus?.on_ac_power === true) {
      await startWallpaper(path)
    } else if (!path) {
      await stopWallpaper()
    }
  })

  try {
    const [path, status] = await Promise.all([
      invoke('get_selected_video'),
      invoke('get_power_status'),
    ])

    currentPowerStatus = status

    if (status?.on_ac_power === true && path) {
      await startWallpaper(path)
    } else {
      await stopWallpaper()
    }
  } catch (error) {
    console.error('Could not initialize wallpaper:', error)
  }
}

async function startWithDiagnostics() {
  try {
    await attachConsole()
    console.info('ChargeMotion: Wallpaper console forwarding enabled.')
  } catch (error) {
    console.error('Could not enable wallpaper console forwarding:', error)
  }

  await initializeWallpaper()
  window.setInterval(() => {
    void inspectPlayback()
  }, 1000)
}

void startWithDiagnostics()