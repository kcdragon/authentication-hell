---
theme: ./theme
title: Welcome to Authentication Hell
info: |
  ## Welcome to Authentication Hell
  A browser-based game written in Ruby, and what it taught me about auth.

  Presented at Philly.rb.
drawings:
  persist: false
transition: slide-left
mdc: true
addons:
  - fancy-arrow
layout: cover
# Most slides are excluded from the Toc; flip this default to false per-slide
# to surface a slide (the section dividers do this).
defaults:
  hideInToc: true
---

# Authentication Hell

<div class="ah-tagline">A browser-based game built with Ruby · RubyConf · Mike Dalton</div>

<div class="mt-10 flex justify-end pr-8">
  <div class="ah-card bg-white p-2 leading-none -rotate-2">
    <img src="./images/level-video-player.png" class="block w-[360px] h-auto" alt="Placeholder: gameplay screenshot of Authentication Hell" />
  </div>
</div>

<!--
Speaker notes go here, after the HTML comment marker.
Press `c` during the talk to open presenter mode.
The cover layout puts the title in an inked block with a hard offset shadow,
matching the app's brutalist headings.
-->

---
layout: two-cols
---

## Hi, I'm Mike Dalton

- Ruby developer
- Staff engineer at Triumph
- Love to build side projects

::right::

<img v-drag="[594,37,244,244]" src="./images/mike-dalton.jpg" />

<img v-drag="[467,322,192,192]" src="./images/triumph-logo.png" />

<img v-drag="[741,336,172,172]" src="./images/calendar-vision-logo.png" class="rounded-2xl" />

---
layout: section
hideInToc: false
---

## Agenda

<Toc minDepth="1" maxDepth="1" columns="2" class="ah-toc mt-6" />

<!--
The agenda is auto-generated from the `# Section` headings on the
`layout: section` divider slides below. The headmatter sets
`defaults: { hideInToc: true }`, so slides are excluded unless they
override it with `hideInToc: false` — only those dividers do, so only
they appear here. Reorder or rename a section and this list follows
automatically. Entries are clickable and the current section
highlights while presenting.
-->

---
layout: section
hideInToc: false
---

# "Authentication Hell"

---
layout: image
image: /images/hell-login-password.png
backgroundSize: cover
---

---
layout: image
image: /images/hell-okta-push.png
backgroundSize: cover
---

---
layout: image
image: /images/hell-vpn-password.png
backgroundSize: cover
---

---
layout: image
image: /images/hell-okta-push.png
backgroundSize: cover
---

---
layout: image
image: /images/hell-aws-vault.png
backgroundSize: cover
---

---
layout: image
image: /images/hell-okta-push.png
backgroundSize: cover
---

---
layout: image
image: /images/hell-okta-github.png
backgroundSize: cover
---

---
layout: image
image: /images/hell-okta-push.png
backgroundSize: cover
---

---
layout: image
image: /images/hell-okta-teleport.png
backgroundSize: cover
---

---
layout: image
image: /images/hell-okta-push.png
backgroundSize: cover
---

---
layout: section
hideInToc: false
---

# What if there was a game?

---
---

<div class="grid grid-cols-3 gap-x-5 gap-y-4 h-full content-center w-fit mx-auto">
  <div class="ah-card bg-white p-2 leading-none">
    <img src="./images/aladdin.png" class="block h-[150px] w-auto mx-auto" alt="Aladdin for Sega Genesis gameplay" />
    <div class="mt-1 text-center text-sm font-bold">Aladdin</div>
  </div>
  <div class="ah-card bg-white p-2 leading-none">
    <img src="./images/crash-warped.jpg" class="block h-[150px] w-auto mx-auto" alt="Crash Bandicoot: Warped — Toad Village" />
    <div class="mt-1 text-center text-sm font-bold">Crash Bandicoot: Warped</div>
  </div>
  <div class="ah-card bg-white p-2 leading-none">
    <img src="./images/ori.jpg" class="block h-[150px] w-auto mx-auto" alt="Ori and the Blind Forest gameplay" />
    <div class="mt-1 text-center text-sm font-bold">Ori and the Blind Forest</div>
  </div>
  <div class="ah-card bg-white p-2 leading-none">
    <img src="./images/sonic-2.png" class="block h-[150px] w-auto mx-auto" alt="Sonic the Hedgehog 2 — Emerald Hill Zone" />
    <div class="mt-1 text-center text-sm font-bold">Sonic the Hedgehog 2</div>
  </div>
  <div class="ah-card bg-white p-2 leading-none">
    <img src="./images/spyro.jpg" class="block h-[150px] w-auto mx-auto" alt="Spyro the Dragon gameplay" />
    <div class="mt-1 text-center text-sm font-bold">Spyro the Dragon</div>
  </div>
  <div class="ah-card bg-white p-2 leading-none">
    <img src="./images/hollow-knight.jpg" class="block h-[150px] w-auto mx-auto" alt="Hollow Knight — the Lake of Unn" />
    <div class="mt-1 text-center text-sm font-bold">Hollow Knight</div>
  </div>
</div>

<!--
I've been a gamer my whole life...
-->

---
layout: image
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
hideInToc: false
---

# DragonRuby

---
layout: image-right
image: images/dragonruby-logo.png
backgroundSize: contain
---

## DragonRuby Game Toolkit

- Cross-platform 2D game engine
  - Desktop
  - Console
  - Steam Deck
  - Mobile
  - Web
- Write games in Ruby!

---
layout: image-right
image: images/mruby-logo.png
backgroundSize: contain
---

## DragonRuby is Ruby

- Custom Ruby runtime
- Based on [mruby](https://mruby.org/)
- Subset of Ruby language specification
- No Gem support

---
layout: image-right
image: images/sdl-logo.png
backgroundSize: contain
---

## Simple DirectMedia Layer

- DragonRuby wraps SDL
- Provides low-level access to graphics, audio, and input
- Supports all platforms

<!--
DragonRuby sits on top of SDL — it's what gives us hardware-accelerated
graphics, audio, and input across every platform, including the WASM build.
-->

---
layout: two-cols-header
---

## tick

::left::

```ruby
def tick(args)
end
```

::right::

- The entry point for your game's code
- `args` gives you everything you need:
  - `args.inputs` - read keyboard, mouse, and controller input
  - `args.outputs` - draw sprites and labels
  - `args.state` - store game state across ticks
- Called **60 times per second** - that's 60 FPS

---
layout: two-cols-header
---

## tick

::left::

````md magic-move
```ruby
def tick(args)
end
```
```ruby {2-5}
def tick(args)
  args.outputs.labels << {
    x: 555, y: 400,
    text: "Hello, DragonRuby!"
  }
end
```
```ruby {7-15}
def tick(args)
  args.outputs.labels << {
    x: 555, y: 400,
    text: "Hello, DragonRuby!"
  }

  args.outputs.labels << {
    x: 555, y: 360,
    text: "Frame: #{args.tick_count}"
  }

  args.outputs.labels << {
    x: 555, y: 320,
    text: "Seconds: #{(args.tick_count / 60).to_i}"
  }
end
```
````

::right::

<div class="flex flex-col items-center justify-center h-full">
  <div class="relative w-full aspect-video">
    <img v-click.hide="1" src="./images/sprite-empty.png" class="absolute inset-0 w-full h-full object-contain" alt="Empty DragonRuby window — tick runs but draws nothing" />
    <img v-click="[1, 2]" src="./images/tick-hello.png" class="absolute inset-0 w-full h-full object-contain" alt="DragonRuby window showing the text Hello, DragonRuby!" />
    <SlidevVideo v-after autoplay loop muted class="absolute inset-0 w-full h-full object-contain">
      <source :src="'/videos/tick-counter.mp4'" type="video/mp4" />
    </SlidevVideo>
  </div>
  <div class="relative w-full text-center text-sm mt-3" style="color: var(--color-muted)">
    <div v-click.hide="1">Empty window — tick runs every frame</div>
    <div v-click="[1, 2]" class="absolute inset-0">A label drawn on screen</div>
    <div v-after class="absolute inset-0">Frame and second counters tick up</div>
  </div>
</div>

---
layout: two-cols-header
---

## Movement

::left::

````md magic-move
```ruby
def tick(args)
  args.state.player ||= {
    x: 100, y: 100,
    w: 50, h: 50,
    path: 'sprites/square/green.png'
  }
end
```
```ruby {8}
def tick(args)
  args.state.player ||= {
    x: 100, y: 100,
    w: 50, h: 50,
    path: 'sprites/square/green.png'
  }

  args.outputs.sprites << args.state.player
end
```
```ruby {8-19}
def tick(args)
  args.state.player ||= {
    x: 100, y: 100,
    w: 50, h: 50,
    path: 'sprites/square/green.png'
  }

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

::right::

<div class="flex flex-col items-center justify-center h-full">
  <div class="relative w-full aspect-video">
    <img v-click.hide="1" src="./images/sprite-empty.png" class="absolute inset-0 w-full h-full object-contain" alt="DragonRuby window that is empty because the sprite is defined but not yet drawn" />
    <img v-click="[1, 2]" src="./images/sprite-rendered.png" class="absolute inset-0 w-full h-full object-contain" alt="DragonRuby window with a green square sprite rendered in the bottom-left" />
    <SlidevVideo v-after autoplay loop muted class="absolute inset-0 w-full h-full object-contain">
      <source :src="'/videos/sprite-moving.mp4'" type="video/mp4" />
    </SlidevVideo>
  </div>
  <div class="relative w-full text-center text-sm mt-3" style="color: var(--color-muted)">
    <div v-click.hide="1">Player defined — nothing drawn yet</div>
    <div v-click="[1, 2]" class="absolute inset-0">Player drawn as a green square</div>
    <div v-after class="absolute inset-0">Arrow keys move the square</div>
  </div>
</div>

---
layout: two-cols-header
---

## Collisions

::left::

````md magic-move
```ruby
def tick(args)
  args.state.terrain ||= [...]
  args.outputs.sprites << args.state.terrain

  args.state.player ||= {...}
  args.outputs.sprites << args.state.player
end
```
```ruby {8-9}
def tick(args)
  args.state.terrain ||= [...]
  args.outputs.sprites << args.state.terrain

  args.state.player ||= {...}
  args.outputs.sprites << args.state.player

  args.state.player.dx = args.inputs.left_right * 2
  args.state.player.x += args.state.player.dx
end
```
```ruby {11-17}
def tick(args)
  args.state.terrain ||= [...]
  args.outputs.sprites << args.state.terrain

  args.state.player ||= {...}
  args.outputs.sprites << args.state.player

  args.state.player.dx = args.inputs.left_right * 2
  args.state.player.x += args.state.player.dx

  collision = args.state.terrain.find do |t|
    t.intersect_rect?(args.state.player)
  end
  
  if collision
    args.state.player.x -= args.state.player.dx
  end
end
```
````

::right::

<div class="flex flex-col items-center justify-center h-full">
  <div class="relative w-full aspect-video">
    <img v-click.hide="1" src="./images/collision-apart.png" class="absolute inset-0 w-full h-full object-contain" alt="DragonRuby window with the player and enemy squares apart" />
    <SlidevVideo v-click="[1, 2]" autoplay loop muted class="absolute inset-0 w-full h-full object-contain">
      <source :src="'/videos/collision.mp4'" type="video/mp4" />
    </SlidevVideo>
    <SlidevVideo v-after autoplay loop muted class="absolute inset-0 w-full h-full object-contain">
      <source :src="'/videos/collision-resolved.mp4'" type="video/mp4" />
    </SlidevVideo>
  </div>
  <div class="relative w-full text-center text-sm mt-3" style="color: var(--color-muted)">
    <div v-click.hide="1">Red player and blue terrain, apart</div>
    <div v-click="[1, 2]" class="absolute inset-0">Player moves right, through the terrain</div>
    <div v-after class="absolute inset-0">Collision detected — player stops at the edge</div>
  </div>
</div>

---
dragPos:
  c: 99,273,179,187
  sdl: 376,155,256,129
  ruby: 692,341,161,161
  native: 70,125,600,365
  dragonruby: 90,140,100,79
---

## Architecture

<div v-drag="'native'" class="border-3 border-dashed border-gray-400 rounded"></div>

<img v-drag="'dragonruby'" data-id="dragonruby" src="./images/dragonruby-logo.png" />

<img v-drag="'c'" data-id="c" src="./images/c-logo.png" />

<img v-drag="'sdl'" data-id="sdl" src="./images/sdl-logo.png" />

<img v-drag="'ruby'" data-id="ruby" src="./images/ruby-logo.png" />

<FancyArrow two-way from="[data-id=c]" to="[data-id=sdl]" />

<FancyArrow two-way from="[data-id=c]" to="[data-id=ruby]">
  <code class="px-2 py-1 rounded bg-white">tick(args)</code>
</FancyArrow>

---
layout: section
hideInToc: false
---

# Authentication Hell: The Game

---
---

## Tech Stack

- DragonRuby game compiled to WASM
- Embedded inside a Rails 8 app
- Built-in Rails Authentication generator
- rotp and webauthn gems

---
---

## WebAssembly (WASM)

<div class="flex items-center justify-center gap-10 mt-10">
  <div class="ah-card bg-white flex items-center justify-center p-6">
    <img src="./images/dragonruby-logo.png" class="max-h-56 w-auto" alt="DragonRuby logo" />
  </div>

  <div class="flex flex-col items-center">
    <span class="font-mono font-bold text-sm uppercase tracking-widest mb-1">compiles to</span>
    <span class="text-6xl leading-none">→</span>
  </div>

  <div class="ah-card bg-white flex items-center justify-center p-6">
    <img src="./images/wasm-logo.png" class="max-h-56 w-auto" alt="WebAssembly (WASM) logo" />
  </div>
</div>

<!--
DragonRuby compiles our game to WebAssembly, which is how it runs in the
browser at native-ish speed — that's the artifact Rails serves at /game.
-->

---
---

## Proof of concept

<div class="flex justify-center mt-6">
  <div class="ah-card bg-white p-2 leading-none">
    <SlidevVideo autoplay loop muted class="block max-h-[340px] w-auto">
      <source :src="'/videos/proof-of-concept.mp4'" type="video/mp4" />
    </SlidevVideo>
  </div>
</div>

---
---

## Discord to the rescue

<div class="flex flex-col items-center gap-3 mt-3">
  <div class="ah-card bg-white p-2 leading-none">
    <img src="./images/discord-heapu8.png" class="block max-h-[300px] w-auto" alt="Discord message diagnosing the Module.HEAPU8 undefined error in the DragonRuby WASM build" />
  </div>
  <div class="ah-card bg-white p-2 leading-none">
    <img src="./images/discord-reply.png" class="block max-w-[630px] h-auto" alt="Discord reply: this is a bug introduced in DragonRuby 7+ it seems" />
  </div>
</div>

---
---

## Each level is a video

<div class="flex justify-center mt-6">
  <div class="ah-card bg-white p-2 leading-none">
    <img src="./images/level-video-player.png" class="block max-h-[340px] w-auto" alt="Game level styled as a corporate training video player, with a scrubber, timestamp, and CC controls below the platformer scene" />
  </div>
</div>


---
---

## Claude Design

<div class="flex justify-center mt-6">
  <div class="ah-card bg-white p-2 leading-none">
    <img src="./images/claude-design.png" class="block max-h-[340px] w-auto" alt="Claude Design canvas redesigning the game screens" />
  </div>
</div>

---
---

## Authenticate in game

<div class="flex justify-center mt-6">
  <div class="ah-card bg-white p-2 leading-none">
    <SlidevVideo autoplay loop muted class="block max-h-[340px] w-auto">
      <source :src="'/videos/authenticate-in-game.mp4'" type="video/mp4" />
    </SlidevVideo>
  </div>
</div>

---
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
---

## Resolve authentication (web)

````md magic-move
```ruby
class Games::PasswordChallengeController < ApplicationController
  def complete
    if Current.session.game_challenges.exists?(kind: "password") && Current.user.authenticate(params[:password])
      Current.session.game_challenges.where(kind: "password").delete_all
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
layout: cover
---

# Questions or feedback?

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
