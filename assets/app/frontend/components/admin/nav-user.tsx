import { router, usePage } from "@inertiajs/react"
import type { SharedProps } from "@/types"
import { ArrowLeft, EllipsisVertical, LogOut, UserCircle } from "lucide-react"

import { userInitials } from "@/lib/user-initials"
import { Avatar, AvatarFallback } from "@/components/ui/avatar"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import {
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  useSidebar,
} from "@/components/ui/sidebar"

export function NavUser() {
  const { currentUser } = usePage<SharedProps>().props
  const { isMobile } = useSidebar()

  const name = currentUser?.name ?? "User"
  const email = currentUser?.email ?? ""
  const initials = currentUser?.name ? userInitials(currentUser.name) : "U"
  const accountId = currentUser?.accountId
  const appPath = (path: string) => {
    if (accountId) {
      return path.replace(/^\/app/, `/app/${accountId}`)
    }

    return path.startsWith("/app/") ? "/app" : path
  }

  return (
    <SidebarMenu>
      <SidebarMenuItem>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <SidebarMenuButton
              size="lg"
              className="data-[state=open]:bg-sidebar-accent data-[state=open]:text-sidebar-accent-foreground"
            >
              <Avatar className="size-10 rounded-lg transition-[width,height] group-data-[collapsible=icon]:size-8">
                <AvatarFallback className="rounded-lg bg-primary text-primary-foreground">
                  {initials}
                </AvatarFallback>
              </Avatar>
              <div className="grid flex-1 text-left text-sm leading-tight">
                <span className="truncate font-medium">{name}</span>
                <span className="truncate text-xs">{email}</span>
              </div>
              <EllipsisVertical className="ml-auto size-4" />
            </SidebarMenuButton>
          </DropdownMenuTrigger>
          <DropdownMenuContent
            className="w-(--radix-dropdown-menu-trigger-width) min-w-56 rounded-lg"
            side={isMobile ? "bottom" : "right"}
            align="end"
            sideOffset={4}
          >
            <DropdownMenuLabel className="p-0 font-normal">
              <div className="flex items-center gap-2 px-1 py-1.5 text-left text-sm">
                <Avatar className="size-10 rounded-lg">
                  <AvatarFallback className="rounded-lg bg-primary text-primary-foreground">
                    {initials}
                  </AvatarFallback>
                </Avatar>
                <div className="grid flex-1 text-left text-sm leading-tight">
                  <span className="truncate font-medium">{name}</span>
                  <span className="truncate text-xs">{email}</span>
                </div>
              </div>
            </DropdownMenuLabel>
            <DropdownMenuSeparator />
            <DropdownMenuGroup>
              <DropdownMenuItem
                onClick={() => router.visit(appPath("/app/settings"))}
              >
                <UserCircle />
                Settings
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => router.visit(appPath("/app"))}>
                <ArrowLeft />
                Back to App
              </DropdownMenuItem>
            </DropdownMenuGroup>
            <DropdownMenuSeparator />
            <DropdownMenuItem onClick={() => router.delete("/logout")}>
              <LogOut />
              Log out
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </SidebarMenuItem>
    </SidebarMenu>
  )
}
