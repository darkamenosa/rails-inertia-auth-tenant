// Flash data from Rails flash messages
export type FlashData = {
  notice?: string
  alert?: string
  success?: string
  warning?: string
  info?: string
}

// Current authenticated user (shared via Inertia)
export type CurrentUser = {
  id: number
  name: string
  email: string
  role: string | null
  staff: boolean
  accountId: number | null
  accountName: string | null
}

// Shared props available on every Inertia page
export type SharedProps = {
  flash?: FlashData
  currentUser: CurrentUser | null
}

// Pagination data from Pagy (via pagination_props helper)
export type PaginationData = {
  page: number
  perPage: number
  total: number
  pages: number
  from: number
  to: number
  hasPrevious: boolean
  hasNext: boolean
}

// Admin: Customer (identity) list item
export type AdminCustomer = {
  id: number
  email: string
  name: string | null
  authMethod: string
  staff: boolean
  status: string
  accountsCount: number
  createdAt: string
}

// Admin: Customer detail (show page)
export type AdminCustomerDetail = {
  id: number
  email: string
  name: string | null
  authMethod: string
  staff: boolean
  status: string
  suspendedAt: string | null
  createdAt: string
  memberships: AdminCustomerMembership[]
}

// Admin: Customer membership (account membership within detail)
export type AdminCustomerMembership = {
  id: number
  accountId: number
  accountName: string
  role: string
  name: string
  active: boolean
  createdAt: string
}
