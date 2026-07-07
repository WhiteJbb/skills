# RelayDesk 2026.3 Release Notes and Policy Update

RelayDesk version 2026.3 ships on March 30, 2026. This release focuses on workspace administration, ticket routing, and billing account controls. Please review the deprecations section before upgrading, and share this document with every workspace administrator on your team.

## What's new in workspaces

- Each workspace now has a dedicated settings page reachable from the sidebar, replacing the shared admin panel.
- Workspace administrators can archive an inactive workspace without deleting its tickets; archived data is retained and searchable.
- The banner shown after archiving now reads: Workspace {workspace_name} has been archived.
- A workspace can be restored by any administrator within 90 days of archiving.

## Ticket routing improvements

- New routing rules can assign a ticket by customer tier, language, or region, evaluated in that order.
- When no rule matches, the ticket falls back to the default queue instead of remaining unassigned.
- The notification template now supports the variable {ticket_id} in both the subject line and the body.
- A ticket that is reopened keeps its original routing history, and the reopen event is recorded in the audit log.

## Escalation policies

- An escalation now fires at most once per ticket per policy, which prevents the duplicate alerts reported in 2026.2.
- Escalation targets can be a person, a team, or an on-call schedule.
- Deleting a policy does not delete past escalation records; they remain visible in the audit log.

## On-call schedules

- An on-call schedule can now span multiple time zones with per-member handoff times.
- The handoff notification includes the variable {agent_name} so the incoming person is named explicitly.
- Gaps in an on-call schedule are highlighted in red in the calendar view seven days in advance.

## Storage and attachments

- Every workspace includes 50 GB of attachment storage; additional storage is billed to the billing account in 10 GB increments.
- Attachments that exceed the per-file limit are not rejected; they are moved to cold storage and remain downloadable from the ticket view.
- Storage usage per workspace is now visible to administrators on the settings page.

## Audit logs

- The audit log now records permission changes, routing rule edits, and escalation policy changes.
- Audit log entries are immutable and are retained for two years on all plans.
- Exporting requires the administrator role and is itself recorded in the audit log.

## Billing account changes

- A billing account can now fund multiple workspaces; usage is itemized per workspace on the monthly invoice.
- Transferring a workspace to a different billing account takes effect at the start of the next billing cycle.
- The invoice email now includes the variable {count} showing the number of active seats.
- Downgrading a billing account requires confirmation from its owner; a pending downgrade can be cancelled until it takes effect.

## Service level commitment

- The uptime commitment for all paid plans is 99.95%, measured monthly and reported on the status page.
- Scheduled maintenance is announced at least five days in advance and does not count against the commitment.

## Refund policy

- Refunds are not issued after 14 days from the payment date, except for customers on an annual plan.
- Customers on an annual plan may request a prorated refund within 14 days of their renewal date.
- Refunds are always issued to the original payment method attached to the billing account.

## Deprecations

- The legacy routing API is deprecated and will stop accepting requests in the release after this one.
- The shared admin panel is removed; its remaining functions have moved to the workspace settings page.
- Ticket export in XML format is deprecated; use the JSON export, which includes the full escalation history.
