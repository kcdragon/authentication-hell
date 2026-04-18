import { Form, usePage } from "@inertiajs/react"
import { CheckCircle2, MailWarning } from "lucide-react"

import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { identityEmailVerificationPath } from "@/routes"
import type { Auth } from "@/types"

export function EmailVerificationBanner() {
  const { auth } = usePage().props as { auth: Auth }

  if (auth.user.verified) {
    return (
      <Card className="w-full border-emerald-500/30 bg-emerald-500/5 sm:w-96">
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-emerald-500">
            <CheckCircle2 className="size-5" />
            Your email is verified
          </CardTitle>
          <CardDescription>
            Identity confirmed. Proceed further into the descent.
          </CardDescription>
        </CardHeader>
      </Card>
    )
  }

  return (
    <Card className="border-destructive/40 bg-destructive/5 w-full sm:w-96">
      <CardHeader>
        <CardTitle className="text-destructive flex items-center gap-2">
          <MailWarning className="size-5" />
          Your email is unverified
        </CardTitle>
        <CardDescription>
          Check your inbox for a verification link. Until you confirm it, your
          descent is on hold.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <Form
          method="post"
          action={identityEmailVerificationPath()}
          options={{ preserveScroll: true }}
        >
          {({ processing }) => (
            <Button type="submit" variant="destructive" disabled={processing}>
              {processing ? "Sending…" : "Resend verification email"}
            </Button>
          )}
        </Form>
      </CardContent>
    </Card>
  )
}
