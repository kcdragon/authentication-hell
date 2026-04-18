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
    <div className="bg-background text-foreground relative flex min-h-svh flex-col items-center justify-center overflow-hidden p-6 md:p-10">
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_at_top,var(--color-destructive)/0.12,transparent_60%)]" />

      <div className="relative z-10 flex w-full max-w-sm flex-col gap-8">
        <div className="flex flex-col items-center gap-4 text-center">
          <Link
            href={rootPath()}
            className="text-muted-foreground hover:text-foreground text-sm font-bold tracking-[0.2em] uppercase transition-colors"
          >
            Authentication <span className="text-destructive">Hell</span>
          </Link>

          {eyebrow && (
            <span className="border-destructive/40 bg-destructive/10 text-destructive inline-block rounded-full border px-3 py-1 text-xs font-medium tracking-[0.2em] uppercase">
              {eyebrow}
            </span>
          )}

          <div className="space-y-2">
            <h1 className="text-3xl font-bold tracking-tight">{title}</h1>
            {description && (
              <p className="text-muted-foreground text-sm">{description}</p>
            )}
          </div>
        </div>

        <div className="bg-card rounded-lg border p-6">{children}</div>

        <p className="text-muted-foreground text-center text-xs">
          By continuing, you consent to receive 2FA codes via carrier pigeon.
        </p>
      </div>
    </div>
  )
}
