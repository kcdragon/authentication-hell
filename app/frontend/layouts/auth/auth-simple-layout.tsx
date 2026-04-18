import { Link } from "@inertiajs/react"
import type { PropsWithChildren } from "react"

import { rootPath } from "@/routes"

interface AuthLayoutProps {
  name?: string
  title?: string
  description?: string
  eyebrow?: string
}

export default function AuthSimpleLayout({
  children,
  title,
  description,
  eyebrow,
}: PropsWithChildren<AuthLayoutProps>) {
  return (
    <div className="relative flex min-h-svh flex-col items-center justify-center overflow-hidden bg-background p-6 text-foreground md:p-10">
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_at_top,var(--color-destructive)/0.12,transparent_60%)]" />

      <div className="relative z-10 flex w-full max-w-sm flex-col gap-8">
        <div className="flex flex-col items-center gap-4 text-center">
          <Link
            href={rootPath()}
            className="text-sm font-bold uppercase tracking-[0.2em] text-muted-foreground transition-colors hover:text-foreground"
          >
            Authentication <span className="text-destructive">Hell</span>
          </Link>

          {eyebrow && (
            <span className="inline-block rounded-full border border-destructive/40 bg-destructive/10 px-3 py-1 text-xs font-medium uppercase tracking-[0.2em] text-destructive">
              {eyebrow}
            </span>
          )}

          <div className="space-y-2">
            <h1 className="text-3xl font-bold tracking-tight">{title}</h1>
            {description && (
              <p className="text-sm text-muted-foreground">{description}</p>
            )}
          </div>
        </div>

        <div className="rounded-lg border bg-card p-6">{children}</div>

        <p className="text-center text-xs text-muted-foreground">
          By continuing, you consent to receive 2FA codes via carrier pigeon.
        </p>
      </div>
    </div>
  )
}
