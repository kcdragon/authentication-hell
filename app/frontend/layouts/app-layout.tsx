import type { ReactNode } from "react"

import AppLayoutTemplate from "@/layouts/app/app-top-bar-layout"

interface AppLayoutProps {
  children: ReactNode
}

export default function AppLayout({ children, ...props }: AppLayoutProps) {
  return <AppLayoutTemplate {...props}>{children}</AppLayoutTemplate>
}
