import type { PropsWithChildren } from "react"

import { AppTopBar } from "@/components/app-top-bar"

export default function AppTopBarLayout({ children }: PropsWithChildren) {
  return (
    <div className="bg-background text-foreground relative min-h-svh">
      <div className="pointer-events-none absolute inset-x-0 top-0 h-[480px] bg-[radial-gradient(ellipse_at_top,var(--color-destructive)/0.10,transparent_60%)]" />
      <AppTopBar />
      <main className="relative z-10 mx-auto w-full max-w-7xl px-4 py-6">
        {children}
      </main>
    </div>
  )
}
