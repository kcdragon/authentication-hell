import { Link, usePage } from "@inertiajs/react"
import { ShieldAlert } from "lucide-react"
import { useState, useSyncExternalStore } from "react"

import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { settingsTwoFactorPath } from "@/routes"
import type { Auth } from "@/types"

const DISMISS_KEY = "ah:totp-cta-dismissed"

function readDismissed() {
  if (typeof window === "undefined") return true
  return window.localStorage.getItem(DISMISS_KEY) === "1"
}

function noop() {
  // no-op unsubscribe for SSR
}

function subscribe(onChange: () => void) {
  if (typeof window === "undefined") return noop
  window.addEventListener("storage", onChange)
  return () => window.removeEventListener("storage", onChange)
}

export function TwoFactorSetupCard() {
  const { auth } = usePage().props as { auth: Auth }
  const persisted = useSyncExternalStore(subscribe, readDismissed, () => true)
  const [locallyDismissed, setLocallyDismissed] = useState(false)
  const dismissed = persisted || locallyDismissed

  if (!auth.user.verified || auth.user.totp_enabled || dismissed) {
    return null
  }

  const dismiss = () => {
    window.localStorage.setItem(DISMISS_KEY, "1")
    setLocallyDismissed(true)
  }

  return (
    <Card className="border-destructive/40 bg-destructive/5 w-full sm:w-96">
      <CardHeader>
        <CardTitle className="text-destructive flex items-center gap-2">
          <ShieldAlert className="size-5" />
          Two factors. Twice the torture.
        </CardTitle>
        <CardDescription>
          Bind your soul — and your authenticator app — for the next layer of
          suffering.
        </CardDescription>
      </CardHeader>
      <CardContent className="flex items-center gap-2">
        <Button asChild variant="destructive">
          <Link href={settingsTwoFactorPath()}>Set up 2FA</Link>
        </Button>
        <Button type="button" variant="ghost" onClick={dismiss}>
          Not now
        </Button>
      </CardContent>
    </Card>
  )
}
