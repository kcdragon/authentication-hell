import { Head } from "@inertiajs/react"

import { EmailVerificationBanner } from "@/components/email-verification-banner"
import AppLayout from "@/layouts/app-layout"

export default function Dashboard() {
  return (
    <AppLayout>
      <Head title="Dashboard" />
      <div className="flex min-h-[calc(100svh-6rem)] items-center justify-center">
        <EmailVerificationBanner />
      </div>
    </AppLayout>
  )
}
