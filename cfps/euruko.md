# Building a browser-based game with DragonRuby and Rails

## Abstract (public program)

Can you write a browser game in Ruby? It turns out you can, and getting started is easier than you'd expect.

This talk discusses a game I've developed about the daily frustration of authentication, where the obstacles are the authentication methods we all fight with. It's built with DragonRuby and embedded in a Rails app, with the game and the web app talking to each other in real time.

We'll see how approachable game development in Ruby has become, especially with AI tools like Claude helping you start, and how a DragonRuby game and a Rails app work together.

## Details for the review committee

**What this talk is**

A look at how I built a browser game where the obstacles are the authentication methods we deal with every day. There's a Ruby game running inside a Rails app, and the two halves communicate while you play.

**The two things I want attendees to take away**

*1. Getting started with game development in Ruby is surprisingly easy.* DragonRuby lets you write a game in Ruby, and AI tools like Claude make the on-ramp shorter still. I came in with no game development background and had something playable quickly. I want to show the audience how low the barrier actually is, so they leave feeling like they could start their own game that weekend.

*2. How the game and the web app talk to each other.* When something happens in the game, it tells Rails, which pushes a response back into the game in real time using Action Cable and Turbo. I'll explain how that connection works, and walk through how I implemented the authentication methods that drive the game, such as passwords, two-factor codes, and passkeys.

**Rough outline**

1. The premise and a live demo, playing through part of the game
2. Writing a game in Ruby with DragonRuby, and how Claude helped me get going
3. Getting the game to run inside a Rails app
4. Making the game and Rails talk to each other in real time with Action Cable and Turbo
5. Implementing the authentication methods that drive the game
6. Takeaways and Q&A

**Intended audience**

Ruby and Rails developers who are curious about using Ruby beyond a typical web app, and anyone who has assumed game development is out of reach. No game development experience required.

**Outcomes**

Attendees will leave knowing that they can write a real browser game in Ruby, that the on-ramp with DragonRuby and AI tooling is genuinely approachable, and how a DragonRuby game and a Rails app can be wired together to talk to each other.

## Pitch for the review committee

Many Ruby developers assume game development is harder than it really is. This talk changes that with a real game I can demo live, built around the authentication methods everyone in the room fights with.

The first thing I want people to walk away with is that getting started is easy. I had no game development background, and with DragonRuby and a tool like Claude I had something playable quickly. I want the audience to leave feeling like they could start their own game right away.

The second is something most Rails developers haven't seen: how a DragonRuby game and a Rails app actually work together, talking to each other in real time.

I'm already presenting an earlier version of this project at RubyConf, so the concept is conference-tested.
