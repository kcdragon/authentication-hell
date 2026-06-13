# The TOTP enemy: a plain purple body. Walking into it triggers the TOTP code
# re-auth flow.
class TotpEnemy < Enemy
  AUTH = :totp
  COLOR = { r: 90, g: 60, b: 160 }
end
