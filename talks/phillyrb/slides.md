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
hideInToc: true
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
layout: section
---

## Agenda

<Toc minDepth="1" maxDepth="1" columns="2" class="ah-toc mt-6" />

<!--
The agenda is auto-generated from the `# Section` headings on the
`layout: section` divider slides below. Every other slide sets
`hideInToc: true`, so only those four dividers appear here. Reorder or
rename a section and this list follows automatically. Entries are
clickable and the current section highlights while presenting.
-->

---
layout: section
---

# "Authentication Hell"

<!-- What do I mean by authentication hell... -->

---
layout: image
hideInToc: true
image: /images/create-password-rules.png
backgroundSize: cover
---

---
layout: image
hideInToc: true
image: /images/okta-verify-push.png
backgroundSize: cover
---

---
layout: image
hideInToc: true
image: /images/authy-totp-codes.png
backgroundSize: cover
---

---
layout: image
hideInToc: true
image: /images/email-otp-code.png
backgroundSize: cover
---

---
layout: image
hideInToc: true
image: /images/security-key-webauthn.png
backgroundSize: cover
---

---
layout: section
---

# A game?

---
layout: image
hideInToc: true
image: /images/rubyconf-cfp.png
backgroundSize: cover
---

<!--
Earlier this year...
-->

---
hideInToc: true
---

## "Weird Ruby" Track

<blockquote class="mt-8 border-l-4 border-ink pl-6 italic" style="font-size: 3rem; line-height: 1.3;">
  ...A program which absolutely should not exist, yet, defying all reason and good taste, does....And we want you to do it in Ruby.
</blockquote>

---
layout: section
---

# DragonRuby & mruby

---
layout: two-cols
hideInToc: true
layoutClass: gap-8
---

## DragonRuby Game Toolkit

- Cross-platform 2D Game Engine
  - Mac, Linux, Windows
  - Steam Deck
  - PS5, Xbox, Nintendo Switch
  - iOS, Android
  - Web (WASM)
- Write your games in Ruby

::right::

<div class="flex items-center justify-center h-full">
  <img src="./images/dragonruby-logo.png" class="max-w-full max-h-80" alt="DragonRuby logo" />
</div>

---
layout: two-cols
hideInToc: true
layoutClass: gap-8
---

## DragonRuby

- Custom Ruby runtime
- Based on [mruby](https://mruby.org/)
- Subset of Ruby language specification
- No Gem support

::right::

<div class="flex items-center justify-center h-full">
  <img src="./images/mruby-logo.png" class="max-w-full max-h-72" alt="mruby logo" />
</div>

---
hideInToc: true
---

## A simple app

````md magic-move
```ruby
def tick(args)
  args.state.player ||= { x: 100,
                          y: 100,
                          w: 50,
                          h: 50,
                          path: 'sprites/square/green.png' }
end
```
```ruby
def tick(args)
  args.state.player ||= { x: 100,
                          y: 100,
                          w: 50,
                          h: 50,
                          path: 'sprites/square/green.png' }

  args.outputs.sprites << args.state.player
end
```
```ruby
def tick(args)
  args.state.player ||= { x: 100,
                          y: 100,
                          w: 50,
                          h: 50,
                          path: 'sprites/square/green.png' }

  if args.inputs.up
    args.state.player.y += 10
  elsif args.inputs.down
    args.state.player.y -= 10
  end

  if args.inputs.left
    args.state.player.x -= 10
  elsif args.inputs.right
    args.state.player.x += 10
  end

  args.outputs.sprites << args.state.player
end
```
````

---
hideInToc: true
---

## A simple app

<div class="absolute inset-0 flex items-center justify-center">
  <a
    href="https://samples.dragonruby.org/samples/02_input_basics/01_moving_a_sprite/index.html"
    target="_blank"
    rel="noopener"
    class="ah-card bg-white px-6 py-4 text-xl font-bold no-underline !text-ink"
  >
    ▶ Demo ↗
  </a>
</div>

---
layout: section
---

# The game

---
hideInToc: true
---

## Tech Stack

- DragonRuby game compiled to WASM
- Embedded inside a Rails 8 app
- Built-in Rails Authentication generator
- rotp and webauthn gems

---
hideInToc: true
---

## Game Demo

<div class="absolute inset-0 flex items-center justify-center">
  <a
    href="http://localhost:3000/game"
    target="_blank"
    rel="noopener"
    class="ah-card bg-white px-6 py-4 text-xl font-bold no-underline !text-ink"
  >
    ▶ Demo ↗
  </a>
</div>

---
hideInToc: true
---

## Authenticate in game

<div class="flex justify-center mt-6">
  <div class="ah-card bg-white p-2 leading-none">
    <SlidevVideo autoplay loop muted class="block max-h-[42vh] w-auto">
      <source :src="'/videos/authenticate-in-game.mp4'" type="video/mp4" />
    </SlidevVideo>
  </div>
</div>

---
hideInToc: true
---

## Trigger authentication (game)

````md magic-move
```ruby
def tick(args)
  args.state.collision_request = DR.http_post(
    "http://localhost:3000/games/password/start"
  )
end
```
```ruby
def tick(args)
  if args.state.collision_request && args.state.collision_request[:complete]
    args.state.collision_request = nil
    args.state.player.frozen = true
  end
  
  args.state.collision_request = DR.http_post(
    "http://localhost:3000/games/password/start"
  )
end
```
```ruby
def tick(args)
  if args.state.collision_request && args.state.collision_request[:complete]
    args.state.collision_request = nil
    args.state.player.frozen = true
  end
  
  args.state.collision_request = DR.http_post(
    "http://localhost:3000/games/password/start"
  )
  
  if args.state.player.frozen
    if !args.state.status_request
      args.state.status_request = DR.http_get("http://localhost:3000/games/password/status")
    end
  end
end
```
```ruby
def tick(args)
  if args.state.collision_request && args.state.collision_request[:complete]
    args.state.collision_request = nil
    args.state.player.frozen = true
  end
  
  args.state.collision_request = DR.http_post(
    "http://localhost:3000/games/password/start"
  )
  
  if args.state.player.frozen
    if !args.state.status_request
      args.state.status_request = DR.http_get("http://localhost:3000/games/password/status")
    elsif args.state.status_request[:complete]
      data = DR.parse_json(args.state.status_request[:response_data])
      if data && data["frozen"] == false
        args.state.player.frozen = false
      end
      args.state.status_request = nil
    end
  end
end
```
````

---
hideInToc: true
---

## Trigger authentication (web)

````md magic-move
```ruby
class Games::PasswordChallengeController < ApplicationController
  skip_forgery_protection only: :start

  def start
    Current.session.game_challenges.find_or_create_by!(kind: "password")
    Turbo::StreamsChannel.broadcast_append_to(
      Current.user, :toasts,
      target: "toasts",
      partial: "games/password_challenge",
      locals: { user: Current.user }
    )
    head :no_content
  end
end
```
```ruby
class Games::PasswordChallengeController < ApplicationController
  skip_forgery_protection only: :start

  def start
    Current.session.game_challenges.find_or_create_by!(kind: "password")
    Turbo::StreamsChannel.broadcast_append_to(
      Current.user, :toasts,
      target: "toasts",
      partial: "games/password_challenge",
      locals: { user: Current.user }
    )
    head :no_content
  end
  
  def status
    render json: { locked: Current.session.game_challenges.exists?(kind: "password") }
  end
end
```
````

---
hideInToc: true
---

## Resolve authentication (web)

````md magic-move
```ruby
class Games::PasswordChallengeController < ApplicationController
  def complete
    if Current.session.game_challenges.exists?(kind: "password") && Current.user.authenticate(params[:password])
      Current.session.game_challenges.where(kind: "password").delete_all
      Achievement::Awarder.call(Current.user, :password_survivor)
      render turbo_stream: turbo_stream.remove("toast")
    else
      render turbo_stream: turbo_stream.replace(
        "toast",
        partial: "games/password_challenge",
        locals: { user: Current.user, error: "Invalid password. Try again." }
      )
    end
  end
end
```
````

---

# What's next?

- Improved communication between game and web app
  - Client-side communication instead of HTTP
- More authentication enemies
- Make the game fun

---
layout: cover
hideInToc: true
---

# Let's Authenticate!

<div class="flex items-start justify-center gap-16 mt-10">
  <div class="flex flex-col items-center">
    <a href="https://authenticationhell.com" target="_blank" rel="noopener" class="ah-tagline !mt-0 mb-3 text-xl !text-ink no-underline">authenticationhell.com</a>
    <div class="ah-card bg-white p-4 leading-none">
      <img src="./images/qr-authenticationhell.svg" class="w-44 h-44" alt="QR code to authenticationhell.com" />
    </div>
  </div>
  <div class="flex flex-col items-center">
    <a href="https://github.com/kcdragon/authentication-hell" target="_blank" rel="noopener" class="ah-tagline !mt-0 mb-3 text-xl !text-ink no-underline flex items-center gap-2">
      <ph-github-logo-fill class="text-2xl" /> kcdragon/authentication-hell
    </a>
    <div class="ah-card bg-white p-4 leading-none">
      <img src="./images/qr-github.svg" class="w-44 h-44" alt="QR code to the source on GitHub" />
    </div>
  </div>
</div>

<div class="absolute bottom-4 left-0 right-0 text-center text-xs text-muted">
  Built with
  <a href="https://www.ruby-lang.org/en/" target="_blank" rel="noopener">Ruby</a>
  ·
  <a href="https://rubyonrails.org/" target="_blank" rel="noopener">Ruby on Rails</a>
  ·
  <a href="https://dragonruby.org/" target="_blank" rel="noopener">DragonRuby</a>
  ·
  <a href="https://sli.dev/" target="_blank" rel="noopener">Slidev</a>
</div>
