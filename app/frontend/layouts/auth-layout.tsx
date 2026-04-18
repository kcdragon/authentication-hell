import type { ReactNode } from "react"

import AuthLayoutTemplate from "@/layouts/auth/auth-simple-layout"

export default function AuthLayout({
  children,
  title,
  description,
  eyebrow,
  ...props
}: {
  children: ReactNode
  title: string
  description: string
  eyebrow?: string
}) {
  return (
    <AuthLayoutTemplate
      title={title}
      description={description}
      eyebrow={eyebrow}
      {...props}
    >
      {children}
    </AuthLayoutTemplate>
  )
}
