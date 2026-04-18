import { Link, usePage } from "@inertiajs/react"

import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { UserMenuContent } from "@/components/user-menu-content"
import { useInitials } from "@/hooks/use-initials"
import { dashboardPath } from "@/routes"
import type { Auth } from "@/types"

export function AppTopBar() {
  const { auth } = usePage().props as { auth: Auth }
  const getInitials = useInitials()

  return (
    <header className="bg-background/70 supports-[backdrop-filter]:bg-background/50 border-destructive/20 sticky top-0 z-40 border-b backdrop-blur">
      <div className="mx-auto flex h-12 w-full max-w-7xl items-center gap-4 px-4">
        <Link
          href={dashboardPath()}
          prefetch
          className="text-foreground text-sm font-bold tracking-[0.2em] uppercase transition-opacity hover:opacity-80"
        >
          Auth <span className="text-destructive">Hell</span>
        </Link>

        <div className="flex-1" />

        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button
              variant="ghost"
              className="data-[state=open]:ring-destructive/40 size-9 rounded-full p-0.5 data-[state=open]:ring-2"
              aria-label="Open account menu"
            >
              <Avatar className="size-8">
                <AvatarImage src={auth.user.avatar} alt={auth.user.name} />
                <AvatarFallback className="bg-neutral-200 text-xs text-black dark:bg-neutral-700 dark:text-white">
                  {getInitials(auth.user.name)}
                </AvatarFallback>
              </Avatar>
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="w-56">
            <UserMenuContent auth={auth} />
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
    </header>
  )
}
