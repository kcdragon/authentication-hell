import { Form, Head, Link } from "@inertiajs/react"
import { ShieldAlert, ShieldCheck } from "lucide-react"

import HeadingSmall from "@/components/heading-small"
import InputError from "@/components/input-error"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import AppLayout from "@/layouts/app-layout"
import SettingsLayout from "@/layouts/settings/layout"
import { newSettingsTwoFactorPath, settingsTwoFactorPath } from "@/routes"

interface TwoFactorShowProps {
  totpEnabled: boolean
  enabledAt: string | null
  recoveryCodes?: string[]
  errors?: { password_challenge?: string[] }
}

function downloadRecoveryCodes(codes: string[]) {
  const body = [
    "Authentication Hell — Two-factor recovery codes",
    "",
    "Each code is single-use. Store them somewhere an authenticator app can't reach.",
    "",
    ...codes,
  ].join("\n")
  const blob = new Blob([body], { type: "text/plain;charset=utf-8" })
  const url = URL.createObjectURL(blob)
  const a = document.createElement("a")
  a.href = url
  a.download = "authentication-hell-recovery-codes.txt"
  document.body.appendChild(a)
  a.click()
  a.remove()
  URL.revokeObjectURL(url)
}

export default function TwoFactorShow({
  totpEnabled,
  enabledAt,
  recoveryCodes,
}: TwoFactorShowProps) {
  return (
    <AppLayout>
      <Head title="Two-factor settings" />

      <SettingsLayout>
        <div className="space-y-6">
          <HeadingSmall
            title="Two-factor authentication"
            description="Bind an authenticator app to your account for an extra layer of suffering."
          />

          {recoveryCodes && recoveryCodes.length > 0 && (
            <Card className="border-destructive/40 bg-destructive/5">
              <CardHeader>
                <CardTitle className="text-destructive flex items-center gap-2">
                  <ShieldAlert className="size-5" />
                  Save these recovery codes
                </CardTitle>
                <CardDescription>
                  Each code works once. We will never show them again. Lose them
                  and you lose the account.
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <pre className="bg-background/60 grid grid-cols-2 gap-2 rounded-md border p-4 font-mono text-sm">
                  {recoveryCodes.map((code) => (
                    <span key={code}>{code}</span>
                  ))}
                </pre>
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => downloadRecoveryCodes(recoveryCodes)}
                >
                  Download as .txt
                </Button>
              </CardContent>
            </Card>
          )}

          {totpEnabled ? (
            <EnabledPanel enabledAt={enabledAt} />
          ) : (
            <DisabledPanel />
          )}
        </div>
      </SettingsLayout>
    </AppLayout>
  )
}

function DisabledPanel() {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <ShieldAlert className="text-destructive size-5" />
          Two-factor is off
        </CardTitle>
        <CardDescription>
          One password is never enough. Add a second factor you will curse every
          morning.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <Button asChild>
          <Link href={newSettingsTwoFactorPath()}>Start setup</Link>
        </Button>
      </CardContent>
    </Card>
  )
}

function EnabledPanel({ enabledAt }: { enabledAt: string | null }) {
  const enabledOn = enabledAt
    ? new Date(enabledAt).toLocaleDateString(undefined, {
        year: "numeric",
        month: "long",
        day: "numeric",
      })
    : null

  return (
    <Card className="border-emerald-500/30 bg-emerald-500/5">
      <CardHeader>
        <CardTitle className="flex items-center gap-2 text-emerald-500">
          <ShieldCheck className="size-5" />
          Two-factor is on
        </CardTitle>
        <CardDescription>
          {enabledOn
            ? `Enabled on ${enabledOn}. Removing it is one less wall between you and the void.`
            : "Removing it is one less wall between you and the void."}
        </CardDescription>
      </CardHeader>
      <CardContent>
        <Form
          method="delete"
          action={settingsTwoFactorPath()}
          options={{ preserveScroll: true }}
          resetOnError={["password_challenge"]}
          resetOnSuccess={["password_challenge"]}
          className="space-y-4"
        >
          {({ errors, processing }) => (
            <>
              <div className="grid gap-2">
                <Label htmlFor="password_challenge">Current password</Label>
                <Input
                  id="password_challenge"
                  name="password_challenge"
                  type="password"
                  autoComplete="current-password"
                  placeholder="Current password"
                />
                <InputError messages={errors.password_challenge} />
              </div>
              <Button type="submit" variant="destructive" disabled={processing}>
                {processing ? "Removing…" : "Disable two-factor"}
              </Button>
            </>
          )}
        </Form>
      </CardContent>
    </Card>
  )
}
