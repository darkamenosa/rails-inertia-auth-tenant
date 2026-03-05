import { useState } from "react"
import { Head, Link, router } from "@inertiajs/react"
import type { AdminCustomerDetail } from "@/types"
import { ChevronLeft } from "lucide-react"

import { formatDateShort } from "@/lib/format-date"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { StatusBadge } from "@/components/admin/ui/status-badge"
import AdminLayout from "@/layouts/admin-layout"

interface Props {
  customer: AdminCustomerDetail
  isSelf: boolean
}

// ─── Overview ───────────────────────────────────────────────────────────────

function OverviewCard({ customer }: { customer: AdminCustomerDetail }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Customer details</CardTitle>
      </CardHeader>
      <CardContent>
        <dl className="grid grid-cols-2 gap-x-6 gap-y-4 text-sm">
          <div className="col-span-2">
            <dt className="text-muted-foreground">Email</dt>
            <dd className="mt-0.5 font-medium">{customer.email}</dd>
          </div>
          <div>
            <dt className="text-muted-foreground">Name</dt>
            <dd className="mt-0.5 font-medium">{customer.name || "—"}</dd>
          </div>
          <div>
            <dt className="text-muted-foreground">Auth method</dt>
            <dd className="mt-0.5 font-medium">{customer.authMethod}</dd>
          </div>
          <div>
            <dt className="text-muted-foreground">Joined</dt>
            <dd className="mt-0.5 font-medium">
              {formatDateShort(customer.createdAt)}
            </dd>
          </div>
          <div>
            <dt className="text-muted-foreground">Accounts</dt>
            <dd className="mt-0.5 font-medium">
              {customer.memberships.length}
            </dd>
          </div>
        </dl>
      </CardContent>
    </Card>
  )
}

// ─── Memberships ────────────────────────────────────────────────────────────

function MembershipsCard({ customer }: { customer: AdminCustomerDetail }) {
  const count = customer.memberships.length

  return (
    <Card>
      <CardHeader>
        <CardTitle>Memberships</CardTitle>
        <CardDescription>
          {count === 0
            ? "No account memberships"
            : `${count} account${count !== 1 ? "s" : ""}`}
        </CardDescription>
      </CardHeader>
      <CardContent className="p-0">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-t">
                <th className="px-4 py-3 text-left text-sm font-medium text-muted-foreground">
                  Account
                </th>
                <th className="px-4 py-3 text-left text-sm font-medium text-muted-foreground">
                  Name
                </th>
                <th className="px-4 py-3 text-left text-sm font-medium text-muted-foreground">
                  Role
                </th>
                <th className="px-4 py-3 text-left text-sm font-medium text-muted-foreground">
                  Status
                </th>
                <th className="px-4 py-3 text-left text-sm font-medium text-muted-foreground">
                  Joined
                </th>
              </tr>
            </thead>
            <tbody>
              {count > 0 ? (
                customer.memberships.map((m) => (
                  <tr
                    key={m.id}
                    className="border-t transition-colors hover:bg-muted/50"
                  >
                    <td className="px-4 py-3 text-sm font-medium">
                      {m.accountName}
                    </td>
                    <td className="px-4 py-3 text-sm">{m.name}</td>
                    <td className="px-4 py-3 text-sm">
                      <Badge
                        variant="outline"
                        className="text-muted-foreground capitalize"
                      >
                        {m.role}
                      </Badge>
                    </td>
                    <td className="px-4 py-3 text-sm">
                      <StatusBadge status={m.active ? "active" : "inactive"} />
                    </td>
                    <td className="px-4 py-3 text-sm">
                      {formatDateShort(m.createdAt)}
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td
                    colSpan={5}
                    className="h-24 text-center text-sm text-muted-foreground"
                  >
                    This identity has no account memberships yet.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </CardContent>
    </Card>
  )
}

// ─── Account Card (sidebar) ─────────────────────────────────────────────────

function AccountCard({
  customer,
  isSelf,
  onDelete,
}: {
  customer: AdminCustomerDetail
  isSelf: boolean
  onDelete: () => void
}) {
  const isSuspended = customer.status === "suspended"

  const handleSuspend = () =>
    router.post(`/admin/customers/${customer.id}/suspension`)
  const handleReactivate = () =>
    router.delete(`/admin/customers/${customer.id}/suspension`)
  const handleGrantStaff = () =>
    router.post(`/admin/customers/${customer.id}/staff_access`)
  const handleRevokeStaff = () =>
    router.delete(`/admin/customers/${customer.id}/staff_access`)

  return (
    <Card>
      <CardHeader>
        <CardTitle>Account</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col">
        {/* Status */}
        <div className="flex flex-col gap-2 pb-4">
          <div className="flex items-center gap-2">
            <StatusBadge status={customer.status} />
            {customer.suspendedAt && (
              <span className="text-xs text-muted-foreground">
                since {formatDateShort(customer.suspendedAt)}
              </span>
            )}
          </div>
          <p className="text-sm text-muted-foreground">
            {isSuspended
              ? "Suspended. Cannot sign in."
              : "Account in good standing."}
          </p>
          {!isSelf &&
            (isSuspended ? (
              <Button
                size="sm"
                variant="outline"
                className="w-fit"
                onClick={handleReactivate}
              >
                Reactivate
              </Button>
            ) : (
              <Button
                size="sm"
                variant="outline"
                className="w-fit"
                onClick={handleSuspend}
              >
                Suspend
              </Button>
            ))}
        </div>

        <div className="border-t" />

        {/* Staff access */}
        <div className="flex flex-col gap-2 py-4">
          <div className="flex items-center justify-between">
            <span className="text-sm font-medium">Staff access</span>
            <Badge
              variant={customer.staff ? "secondary" : "outline"}
              className="text-muted-foreground"
            >
              {customer.staff ? "Staff" : "No access"}
            </Badge>
          </div>
          <p className="text-sm text-muted-foreground">
            {customer.staff
              ? "Has access to the admin panel."
              : "Cannot access the admin panel."}
          </p>
          {!isSelf &&
            (customer.staff ? (
              <Button
                size="sm"
                variant="outline"
                className="w-fit"
                onClick={handleRevokeStaff}
              >
                Revoke access
              </Button>
            ) : (
              <Button
                size="sm"
                variant="outline"
                className="w-fit"
                onClick={handleGrantStaff}
              >
                Grant access
              </Button>
            ))}
        </div>

        {/* Danger zone */}
        {!isSelf && (
          <>
            <div className="border-t" />
            <div className="flex flex-col gap-2 pt-4">
              <span className="text-sm font-medium">Danger zone</span>
              <p className="text-sm text-muted-foreground">
                Permanently delete this customer and all their data.
              </p>
              <Button
                size="sm"
                variant="destructive"
                className="w-fit"
                onClick={onDelete}
              >
                Delete customer
              </Button>
            </div>
          </>
        )}
      </CardContent>
    </Card>
  )
}

// ─── Page ───────────────────────────────────────────────────────────────────

export default function AdminCustomerShow({ customer, isSelf }: Props) {
  const [deleteOpen, setDeleteOpen] = useState(false)

  const handleDelete = () =>
    router.delete(`/admin/customers/${customer.id}`, {
      onSuccess: () => setDeleteOpen(false),
    })

  return (
    <AdminLayout>
      <Head title={customer.name || customer.email} />

      <div className="flex flex-col gap-4">
        {/* Page header */}
        <div className="flex items-center gap-2.5">
          <Link
            href="/admin/customers"
            aria-label="Back to customers"
            className="rounded p-1 text-muted-foreground hover:bg-muted hover:text-foreground"
          >
            <ChevronLeft className="size-4" />
          </Link>
          <h1 className="min-w-0 truncate text-lg font-semibold">
            {customer.name || customer.email}
          </h1>
          <StatusBadge status={customer.status} />
        </div>

        {/* Main + sidebar grid */}
        <div className="grid items-start gap-4 lg:grid-cols-5">
          <div className="flex flex-col gap-4 lg:col-span-3">
            <OverviewCard customer={customer} />
            <MembershipsCard customer={customer} />
          </div>
          <div className="lg:col-span-2">
            <AccountCard
              customer={customer}
              isSelf={isSelf}
              onDelete={() => setDeleteOpen(true)}
            />
          </div>
        </div>
      </div>

      {/* Delete confirmation */}
      <Dialog open={deleteOpen} onOpenChange={setDeleteOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Delete this customer?</DialogTitle>
            <DialogDescription>
              This will permanently delete{" "}
              <span className="font-medium text-foreground">
                {customer.email}
              </span>{" "}
              and all their data, including all account memberships. This cannot
              be undone.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleteOpen(false)}>
              Cancel
            </Button>
            <Button variant="destructive" onClick={handleDelete}>
              Yes, delete customer
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </AdminLayout>
  )
}
