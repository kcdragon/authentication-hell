# The passkey enemy: a plain blue body. Walking into it triggers the passkey
# re-auth flow.
class PasskeyEnemy < Enemy
  AUTH = :passkey
  COLOR = { r: 60, g: 120, b: 200 }
end
