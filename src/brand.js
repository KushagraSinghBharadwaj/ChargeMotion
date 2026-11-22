// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// BRAND â€” the ONE place to swap in the official ChargeMotion logo.
// Everything in the UI (sidebar, About page) calls brandLogo().
// Replace PLACEHOLDER_MARK (or return an <img src="...">) when the
// official logo is supplied. The window/tray icons live separately
// in src-tauri/icons.
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
export const BRAND_NAME = 'ChargeMotion'

const PLACEHOLDER_MARK = `
  <svg viewBox="0 0 32 32" aria-hidden="true">
    <path d="M16 2.5 27.7 9.25v13.5L16 29.5 4.3 22.75V9.25z" class="logo-hex"/>
    <path d="m17.2 8-5.2 9h4.2l-1.4 7 5.2-9h-4.2z" class="logo-bolt"/>
  </svg>`

export function brandLogo() {
  return `<span class="logo-mark" data-logo="placeholder">${PLACEHOLDER_MARK}</span>`
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// CREATOR MEDAL â€” shown at the bottom of every page.
// To change the displayed name, edit CREATOR_NAME only.
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
export const CREATOR_NAME = 'Kushagra Singh Bharadwaj'

export function creatorMedal() {
  return `
    <div class="medal">
      <span class="medal-pin"></span>
      <div class="medal-swing">
        <div class="medal-strap" aria-hidden="true"><span>CHARGEMOTION</span></div>
        <div class="medal-clip" aria-hidden="true"></div>
        <div class="medal-card-wrap">
          <div class="medal-card-back" aria-hidden="true"></div>
          <div class="medal-card">
            <span class="medal-slot" aria-hidden="true"></span>
            <span class="medal-dots" aria-hidden="true"></span>
            <p class="medal-text"><span>Made by</span> <strong>${CREATOR_NAME}</strong></p>
            <div class="medal-foot" aria-hidden="true"><i></i>${BRAND_NAME}</div>
          </div>
        </div>
      </div>
    </div>`
}

