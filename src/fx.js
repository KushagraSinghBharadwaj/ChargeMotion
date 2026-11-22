// Visual-effects controller: ambient particles, quality tiers, activity gating.
// Everything here is cosmetic and never touches application state.

const root = document.documentElement
const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)')

let tier = 'full' // 'full' | 'lite' | 'static'
let canvas = null
let ctx = null
let particles = []
let raf = 0
let lastFrame = 0
let drawTimeSum = 0
let drawSamples = 0
let width = 0
let height = 0
let dpr = 1

const COUNT = { full: 46, lite: 18 }
const FRAME_MS = 1000 / 30 // ambient layer is capped at 30 fps

function detectTier() {
  if (reduceMotion.matches) return 'static'
  const cores = navigator.hardwareConcurrency || 4
  const memory = navigator.deviceMemory || 8
  return cores <= 4 || memory <= 4 ? 'lite' : 'full'
}

function makeParticles() {
  const count = COUNT[tier] || 0
  particles = Array.from({ length: count }, () => ({
    x: Math.random(),
    y: Math.random(),
    r: 0.6 + Math.random() * 1.5,
    v: 0.004 + Math.random() * 0.012,
    sway: 0.01 + Math.random() * 0.02,
    phase: Math.random() * Math.PI * 2,
  }))
}

function sizeCanvas() {
  if (!canvas) return
  dpr = Math.min(window.devicePixelRatio || 1, tier === 'full' ? 1.5 : 1)
  width = window.innerWidth
  height = window.innerHeight
  canvas.width = Math.round(width * dpr)
  canvas.height = Math.round(height * dpr)
}

function draw(time) {
  if (!ctx) return
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
  ctx.clearRect(0, 0, width, height)
  const charging = root.dataset.power === 'on'
  const boost = charging ? 1 : 0.55

  for (const p of particles) {
    const x = (p.x + Math.sin(time / 4000 + p.phase) * p.sway) * width
    const y = p.y * height
    const alpha = (0.18 + 0.32 * (0.5 + 0.5 * Math.sin(time / 1800 + p.phase))) * boost
    ctx.beginPath()
    ctx.fillStyle = `rgba(184,245,200,${alpha.toFixed(3)})`
    ctx.arc(x, y, p.r, 0, Math.PI * 2)
    ctx.fill()
  }
}

function step(dt) {
  const speed = root.dataset.power === 'on' ? 1 : 0.5
  for (const p of particles) {
    p.y -= p.v * speed * (dt / 1000)
    if (p.y < -0.02) {
      p.y = 1.02
      p.x = Math.random()
    }
  }
}

function degradeIfSlow() {
  if (drawSamples < 90) return
  const avg = drawTimeSum / drawSamples
  drawTimeSum = 0
  drawSamples = 0
  if (tier === 'full' && avg > 5) setTier('lite')
  else if (tier === 'lite' && avg > 8) setTier('static')
}

function loop(now) {
  raf = requestAnimationFrame(loop)
  if (now - lastFrame < FRAME_MS) return
  const dt = Math.min(now - lastFrame, 100)
  lastFrame = now
  const t0 = performance.now()
  step(dt)
  draw(now)
  drawTimeSum += performance.now() - t0
  drawSamples += 1
  degradeIfSlow()
}

function startLoop() {
  if (raf || tier === 'static' || root.dataset.active === 'false') return
  lastFrame = performance.now()
  raf = requestAnimationFrame(loop)
}

function stopLoop() {
  if (raf) cancelAnimationFrame(raf)
  raf = 0
}

function setTier(next) {
  tier = next
  root.dataset.fx = next
  makeParticles()
  sizeCanvas()
  stopLoop()
  if (next === 'static') {
    draw(0) // one still frame, no animation
  } else {
    startLoop()
  }
}

function updateActive() {
  const active = !document.hidden && document.hasFocus()
  root.dataset.active = String(active)
  if (active) startLoop()
  else stopLoop()
}

export function initFx() {
  canvas = document.querySelector('#fx-canvas')
  ctx = canvas ? canvas.getContext('2d') : null

  root.dataset.active = 'true'
  setTier(detectTier())
  updateActive()

  document.addEventListener('visibilitychange', updateActive)
  window.addEventListener('focus', updateActive)
  window.addEventListener('blur', updateActive)

  let resizeTimer = 0
  window.addEventListener('resize', () => {
    window.clearTimeout(resizeTimer)
    resizeTimer = window.setTimeout(() => {
      sizeCanvas()
      if (tier === 'static') draw(0)
    }, 120)
  })

  reduceMotion.addEventListener('change', () => setTier(detectTier()))
}

// Pointer parallax for the hero display. Writes CSS variables only when the
// pointer moves (rAF-throttled); there is no continuous loop.
export function bindHeroTilt(hero) {
  const rig = hero?.querySelector('.rig')
  if (!rig) return

  let frame = 0
  let nx = 0
  let ny = 0

  const apply = () => {
    frame = 0
    rig.style.setProperty('--ry', `${-14 + nx * 8}deg`)
    rig.style.setProperty('--rx', `${6 - ny * 6}deg`)
  }

  hero.addEventListener('pointermove', event => {
    if (root.dataset.fx === 'static' || root.dataset.active === 'false') return
    const box = hero.getBoundingClientRect()
    nx = ((event.clientX - box.left) / box.width - 0.5) * 2
    ny = ((event.clientY - box.top) / box.height - 0.5) * 2
    if (!frame) frame = requestAnimationFrame(apply)
  })

  hero.addEventListener('pointerleave', () => {
    nx = 0
    ny = 0
    if (!frame) frame = requestAnimationFrame(apply)
  })
}

// Card tilt + cursor spotlight, delegated from one host element so page
// re-renders never stack listeners. `.tilt` cards rotate slightly; `.spot`
// panels only get the light/border glow that follows the cursor.
export function initCardFx(host) {
  let target = null
  let frame = 0
  let px = 0
  let py = 0

  const reset = node => {
    if (!node) return
    for (const name of ['--tx', '--ty', '--mx', '--my']) node.style.removeProperty(name)
  }

  const apply = () => {
    frame = 0
    if (!target || !target.isConnected) return
    const box = target.getBoundingClientRect()
    const nx = (px - box.left) / box.width
    const ny = (py - box.top) / box.height
    target.style.setProperty('--mx', `${(nx * 100).toFixed(1)}%`)
    target.style.setProperty('--my', `${(ny * 100).toFixed(1)}%`)
    if (target.classList.contains('tilt')) {
      target.style.setProperty('--tx', `${((0.5 - ny) * 7).toFixed(2)}deg`)
      target.style.setProperty('--ty', `${((nx - 0.5) * 9).toFixed(2)}deg`)
    }
  }

  host.addEventListener('pointermove', event => {
    if (root.dataset.fx === 'static' || root.dataset.active === 'false') return
    const next = event.target.closest?.('.tilt, .spot') || null
    if (next !== target) {
      reset(target)
      target = next
    }
    if (!target) return
    px = event.clientX
    py = event.clientY
    if (!frame) frame = requestAnimationFrame(apply)
  })

  host.addEventListener('pointerleave', () => {
    reset(target)
    target = null
  })
}

// Creator medal: a damped pendulum that reacts to the cursor. The loop runs
// only while the medal is moving and stops once it has settled. Touch /
// no-hover devices use a CSS idle sway instead; reduced motion keeps it still.
export function initMedal() {
  const canHover = window.matchMedia('(hover: hover) and (pointer: fine)')
  const RANGE = 170 // px: how close the cursor must be to disturb the medal
  const K = 90 // spring stiffness
  const C = 7 // damping (under-damped, so it swings back like a pendulum)

  let theta = 0
  let omega = 0
  let target = 0
  let ry = 0
  let ryTarget = 0
  let raf = 0
  let aimFrame = 0
  let last = 0
  let px = 0
  let py = 0
  let kick = 0
  let pointerInside = false

  const medal = () => document.querySelector('.medal')
  const allowed = () =>
    canHover.matches &&
    !reduceMotion.matches &&
    root.dataset.fx !== 'static' &&
    root.dataset.active !== 'false'
  const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v))

  const write = el => {
    el.style.setProperty('--swing', theta.toFixed(3))
    el.style.setProperty('--ry', ry.toFixed(3))
    el.style.setProperty('--lag', clamp(-omega * 0.22, -7, 7).toFixed(3))
  }

  const clear = el => {
    if (!el) return
    el.style.removeProperty('--swing')
    el.style.removeProperty('--ry')
    el.style.removeProperty('--lag')
  }

  const frame = now => {
    raf = 0
    const el = medal()
    if (!el) return
    const dt = Math.min((now - last) / 1000, 0.033)
    last = now

    omega += kick
    kick = 0
    omega += (K * (target - theta) - C * omega) * dt
    theta += omega * dt
    ry += (ryTarget - ry) * Math.min(1, dt * 8)
    write(el)

    const settled =
      target === 0 && Math.abs(theta) < 0.02 && Math.abs(omega) < 0.05 && Math.abs(ry) < 0.05
    if (settled) {
      theta = omega = ry = 0
      clear(el)
      return
    }
    raf = requestAnimationFrame(frame)
  }

  const wake = () => {
    if (raf) return
    last = performance.now()
    raf = requestAnimationFrame(frame)
  }

  const aim = () => {
    aimFrame = 0
    const el = medal()
    if (!el || !pointerInside || !allowed()) {
      target = 0
      ryTarget = 0
      if (raf || theta) wake()
      return
    }
    const box = el.getBoundingClientRect()
    const dx = px - (box.left + box.width / 2)
    const dy = py - (box.top + box.height * 0.55)
    const near = clamp(1 - Math.hypot(dx, dy) / RANGE, 0, 1)
    const push = clamp(dx / RANGE, -1, 1)

    target = push * near * 14
    ryTarget = -push * near * 16
    if (near > 0 || raf || theta) wake()
  }

  const schedule = () => {
    if (!aimFrame) aimFrame = requestAnimationFrame(aim)
  }

  window.addEventListener('pointermove', event => {
    if (!allowed()) return
    pointerInside = true
    px = event.clientX
    py = event.clientY
    // fast sideways passes give the medal a small extra nudge
    kick = clamp((event.movementX || 0) * 0.05, -3, 3)
    schedule()
  })

  const release = () => {
    pointerInside = false
    schedule()
  }
  document.documentElement.addEventListener('pointerleave', release)
  window.addEventListener('blur', release)
}
