import { Form, Head, Link } from "@inertiajs/react"
import { useState } from "react"

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
import { confirmSettingsTwoFactorPath, settingsTwoFactorPath } from "@/routes"

interface TwoFactorNewProps {
  qrSvg: string
  secret: string
  issuer: string
  email: string
  errors?: { code?: string | string[] }
}

export default function TwoFactorNew({
  qrSvg,
  secret,
  issuer,
  email,
  errors,
}: TwoFactorNewProps) {
  const [copied, setCopied] = useState(false)

  const copySecret = () => {
    navigator.clipboard
      .writeText(secret)
      .then(() => {
        setCopied(true)
        setTimeout(() => setCopied(false), 1500)
      })
      .catch(() => {
        // ignore — clipboard access may be blocked
      })
  }

  const codeErrors = errors?.code
    ? Array.isArray(errors.code)
      ? errors.code
      : [errors.code]
    : undefined

  return (
    <AppLayout>
      <Head title="Set up two-factor" />

      <SettingsLayout>
        <div className="space-y-6">
          <span className="border-destructive/40 bg-destructive/10 text-destructive inline-block rounded-full border px-3 py-1 text-xs font-medium tracking-[0.2em] uppercase">
            Level 2 unlocked
          </span>

          <HeadingSmall
            title="Scan the sigil"
            description="Open your authenticator app, scan the code, then type what it shows."
          />

          <Card>
            <CardHeader>
              <CardTitle>Step 1 — Pair your device</CardTitle>
              <CardDescription>
                Scan the QR code with an authenticator app (1Password, Authy,
                Google Authenticator). Can&apos;t scan? Enter the key by hand.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="grid gap-6 sm:grid-cols-[auto_1fr] sm:items-center">
                <div
                  className="bg-background inline-block rounded-md border p-2"
                  aria-label={`QR code for ${issuer} (${email})`}
                  dangerouslySetInnerHTML={{ __html: qrSvg }}
                />
                <div className="space-y-3">
                  <div>
                    <p className="text-muted-foreground text-xs tracking-widest uppercase">
                      Account
                    </p>
                    <p className="font-medium">
                      {issuer} ({email})
                    </p>
                  </div>
                  <div>
                    <p className="text-muted-foreground text-xs tracking-widest uppercase">
                      Manual entry key
                    </p>
                    <div className="flex items-center gap-2">
                      <code className="bg-muted rounded px-2 py-1 font-mono text-sm break-all">
                        {secret}
                      </code>
                      <Button
                        type="button"
                        variant="outline"
                        size="sm"
                        onClick={copySecret}
                      >
                        {copied ? "Copied" : "Copy"}
                      </Button>
                    </div>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Step 2 — Confirm with a code</CardTitle>
              <CardDescription>
                Enter the six digits your authenticator app is showing right
                now.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <Form
                method="post"
                action={confirmSettingsTwoFactorPath()}
                options={{ preserveScroll: true }}
                resetOnError={["code"]}
                className="space-y-4"
              >
                {({ processing, errors: formErrors }) => {
                  const merged =
                    (formErrors?.code as string | string[] | undefined) ??
                    codeErrors

                  return (
                    <>
                      <div className="grid gap-2">
                        <Label htmlFor="code">Authentication code</Label>
                        <Input
                          id="code"
                          name="code"
                          inputMode="numeric"
                          pattern="[0-9]*"
                          maxLength={6}
                          autoComplete="one-time-code"
                          placeholder="123456"
                          required
                        />
                        <InputError
                          messages={
                            Array.isArray(merged)
                              ? merged
                              : merged
                                ? [merged]
                                : undefined
                          }
                        />
                      </div>

                      <div className="flex items-center gap-3">
                        <Button type="submit" disabled={processing}>
                          {processing ? "Confirming…" : "Confirm and enable"}
                        </Button>
                        <Button asChild variant="ghost">
                          <Link href={settingsTwoFactorPath()}>Cancel</Link>
                        </Button>
                      </div>
                    </>
                  )
                }}
              </Form>
            </CardContent>
          </Card>
        </div>
      </SettingsLayout>
    </AppLayout>
  )
}
