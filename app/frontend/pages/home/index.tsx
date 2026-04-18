import { Head, Link, usePage } from "@inertiajs/react"

import { Button } from "@/components/ui/button"
import { dashboardPath, signInPath, signUpPath } from "@/routes"

export default function Welcome() {
  const { auth } = usePage().props

  return (
    <>
      <Head title="Authentication Hell" />

      <div className="relative flex min-h-screen flex-col items-center justify-center overflow-hidden bg-background p-6 text-foreground">
        <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_at_top,var(--color-destructive)/0.12,transparent_60%)]" />

        <main className="relative z-10 flex w-full max-w-2xl flex-col items-center text-center">
          <span className="mb-6 inline-block rounded-full border border-destructive/40 bg-destructive/10 px-3 py-1 text-xs font-medium uppercase tracking-[0.2em] text-destructive">
            Now with 47 MFA methods
          </span>

          <h1 className="text-5xl font-bold tracking-tight md:text-7xl">
            Authentication <span className="text-destructive">Hell</span>
          </h1>

          <p className="mt-4 text-lg text-muted-foreground md:text-xl">
            Login. Verify. Captcha. Repeat. Win?
          </p>

          {auth.user ? (
            <div className="mt-10">
              <Button asChild size="lg">
                <Link href={dashboardPath()}>Continue Suffering →</Link>
              </Button>
            </div>
          ) : (
            <div className="mt-10 grid w-full max-w-xl gap-4 md:grid-cols-2">
              <CtaCard
                eyebrow="Been here before?"
                description="Resume your doomed quest to remain logged in."
                button={
                  <Button asChild size="lg" variant="outline" className="w-full">
                    <Link href={signInPath()}>Sign In</Link>
                  </Button>
                }
              />
              <CtaCard
                eyebrow="First time suffering?"
                description="Create an account. Begin the descent."
                button={
                  <Button asChild size="lg" className="w-full">
                    <Link href={signUpPath()}>Create Account</Link>
                  </Button>
                }
              />
            </div>
          )}

          <p className="mt-8 text-xs text-muted-foreground">
            By continuing, you consent to receive 2FA codes via carrier pigeon.
          </p>
        </main>
      </div>
    </>
  )
}

function CtaCard({
  eyebrow,
  description,
  button,
}: {
  eyebrow: string
  description: string
  button: React.ReactNode
}) {
  return (
    <div className="flex flex-col gap-3 rounded-lg border bg-card p-6 text-left">
      <h2 className="text-sm font-semibold uppercase tracking-wider text-muted-foreground">
        {eyebrow}
      </h2>
      <p className="text-sm text-card-foreground">{description}</p>
      <div className="mt-auto pt-2">{button}</div>
    </div>
  )
}
