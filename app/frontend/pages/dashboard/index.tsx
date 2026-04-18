import { Head } from "@inertiajs/react"

import { EmailVerificationBanner } from "@/components/email-verification-banner"
import { TwoFactorSetupCard } from "@/components/two-factor-setup-card"
import AppLayout from "@/layouts/app-layout"

export default function Dashboard() {
  return (
    <AppLayout>
      <Head title="Dashboard" />
      <div className="flex min-h-[calc(100svh-6rem)] flex-col items-center justify-center gap-6">
        <EmailVerificationBanner />
        <TwoFactorSetupCard />
      </div>
    </AppLayout>
  )
}
