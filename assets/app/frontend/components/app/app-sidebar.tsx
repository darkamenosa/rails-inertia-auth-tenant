import { usePage } from "@inertiajs/react"
import { FolderOpen, LayoutDashboard } from "lucide-react"

import { withAccountScope } from "@/lib/account-scope"
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
  SidebarRail,
} from "@/components/ui/sidebar"
import { NavUser } from "@/components/app/nav-user"
import { TeamSwitcher } from "@/components/app/team-switcher"
import { NavMain } from "@/components/shared/nav-main"

export function AppSidebar(props: React.ComponentProps<typeof Sidebar>) {
  const { url } = usePage()
  const scopedPath = (path: string) => withAccountScope(url, path)
  const navMain = [
    {
      title: "Dashboard",
      url: scopedPath("/app/dashboard"),
      icon: LayoutDashboard,
    },
    {
      title: "Projects",
      url: scopedPath("/app/projects"),
      icon: FolderOpen,
    },
  ]

  return (
    <Sidebar collapsible="icon" {...props}>
      <SidebarHeader>
        <TeamSwitcher />
      </SidebarHeader>
      <SidebarContent>
        <NavMain items={navMain} />
      </SidebarContent>
      <SidebarFooter>
        <NavUser />
      </SidebarFooter>
      <SidebarRail />
    </Sidebar>
  )
}
