---
# No external theme — the look comes from ./style.css + ./layouts,
# mirroring the app's "HARD MODE" design system.
title: Welcome to Authentication Hell
info: |
  ## Welcome to Authentication Hell
  A browser-based game written in Ruby, and what it taught me about auth.

  Presented at Philly.rb.
drawings:
  persist: false
transition: slide-left
mdc: true
layout: cover
---

# Authentication Hell

<div class="ah-tagline">A browser-based game built with Ruby · Philly.rb · Mike Dalton</div>

<!--
Speaker notes go here, after the HTML comment marker.
Press `c` during the talk to open presenter mode.
The cover layout puts the title in an inked block with a hard offset shadow,
matching the app's brutalist headings.
-->

---
layout: image
image: ./images/create-password-rules.png
backgroundSize: cover
---

---
layout: image
image: ./images/okta-verify-push.png
backgroundSize: cover
---

---
layout: image
image: ./images/authy-totp-codes.png
backgroundSize: cover
---

---
layout: image
image: ./images/email-otp-code.png
backgroundSize: cover
---

---
layout: image
image: ./images/security-key-webauthn.png
backgroundSize: cover
---

---
layout: two-cols
layoutClass: gap-8
---

## DragonRuby Game Toolkit

- Cross-platform 2D Game Engine
  - Mac, Linux, Windows
  - Steam Deck
  - PS5, Xbox, Nintendo Switch
  - iOS, Android
  - Web (WASM)
- Uses [SDL](https://www.libsdl.org/) and [mruby](https://mruby.org/)
- Write your games in Ruby

::right::

<div class="flex items-center justify-center h-full">
  <img src="./images/dragonruby-logo.png" class="max-w-full max-h-80" alt="DragonRuby logo" />
</div>

---

<Placeholder />

## Why this talk exists

- Technology keeps getting better, yet we still juggle passwords, push notifications, codes…
- What if authentication was *literally* never ending?
- So I built a game about it — in Ruby, in the browser.

<div class="mt-8 flex gap-2">
  <span class="ah-badge ah-badge--password">Password</span>
  <span class="ah-badge ah-badge--totp">TOTP</span>
  <span class="ah-badge ah-badge--passkey">Passkey</span>
</div>

<!-- The badges are the app's real role colors: amber/purple/blue. -->

---
layout: section
---

<Placeholder />

# Demo

<div class="ah-tagline">authenticationhell.com</div>

<!--
Live demo slot. Either:
  - Alt-tab to the running app, or
  - Drop a screenshot/gif below (see the next slide for how to embed).
-->

---

<Placeholder />

## Embedding a screenshot

Put images in `./images/` next to this file, then reference them. Once you
drop a real screenshot in, uncomment the line below:

<!-- ![game level one](./images/level-one.png) -->

<div class="ah-card mt-6 text-muted">
  Screenshot goes here — the <code>.ah-card</code> frame matches the app's raised cards.
</div>

<!--
Card placeholder kept so the scaffold builds before any image exists.
Replace with a real screenshot from the game and uncomment the image line.
-->

---

<Placeholder />

## Pulling in real code from the repo

Slidev can import line ranges from a source file, so the slide always matches
what's actually in the game. Once a real auth model exists, add a
transclusion here, e.g.:

```
<<< ../../../app/models/user.rb#login {1-12}
```

<!--
Path is relative to this slides.md; `../../../` climbs
talks/phillyrb -> talks -> repo root. Shown fenced (not live) so the
scaffold builds before app/models/user.rb exists — drop the fences to
make it a real import.
-->

---

<Placeholder />

## A fenced code block

```ruby
class SessionsController < ApplicationController
  def create
    user = User.find_by(email: params[:email])
    if user&.authenticate(params[:password])
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "Try again."
    end
  end
end
```

---
layout: two-cols
layoutClass: gap-8
---

<Placeholder />

## The auth gauntlet

- <span class="ah-password">Passwords</span>
- Email confirmation
- Password reset
- <span class="ah-totp">TOTP 2FA</span>
- Recovery codes
- <span class="ah-passkey">WebAuthn passkeys</span>

::right::

## In the game

Each enemy collision forces you to re-authenticate mid-play — with a
progressively more annoying method.

<div class="ah-card mt-4">
  Collide → a challenge toast pops in the app's role color, and the run
  freezes until you answer it.
</div>

<!-- Tie the real auth stack to the game mechanic; colors match the app. -->

---
layout: cover
---

# Let's Authenticate!

<div class="flex items-start justify-center gap-16 mt-10">
  <div class="flex flex-col items-center">
    <div class="ah-tagline !mt-0 mb-3 text-xl !text-ink">authenticationhell.com</div>
    <div class="ah-card bg-white p-4 leading-none">
      <img src="./images/qr-authenticationhell.svg" class="w-44 h-44" alt="QR code to authenticationhell.com" />
    </div>
  </div>
  <div class="flex flex-col items-center">
    <div class="ah-tagline !mt-0 mb-3 text-xl !text-ink flex items-center gap-2">
      <ph-github-logo-fill class="text-2xl" /> kcdragon/authentication-hell
    </div>
    <div class="ah-card bg-white p-4 leading-none">
      <img src="./images/qr-github.svg" class="w-44 h-44" alt="QR code to the source on GitHub" />
    </div>
  </div>
</div>
