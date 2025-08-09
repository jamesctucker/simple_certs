## Exercise 3: Stale Transfer Cancellation

### Assumptions Made

- **24-hour threshold**: I chose 24 hours as a starting point, though this might be too aggressive for real users. Weekend transfers or different time zones could cause legitimate delays. In production, I'd probably start with 72 hours (3 days) or even a week, then adjust based on user feedback and transfer completion data.
- **Revert, don't delete**: When a transfer goes stale, I return it to the original owner rather than deleting it entirely. This preserves the certificate and gives the sender another chance.
- **Frequent monitoring**: The job runs every 5-15 minutes to catch stale transfers quickly without overwhelming the system.

### Trade-offs Considered

**Correctness vs Speed:**

I prioritized getting it right over getting it fast. Used `find_each` instead of bulk SQL updates so I can handle errors on individual records gracefully. Using `find_each` also automatically batches the queries into a default of 1000 records, which is a good balance between performance and memory usage. ActiveJob's built-in retry mechanism means temporary failures won't lose data, even though it's not the fastest approach.

**Completeness vs Scope:**

Given the 1-2 hour time limit, I focused on solving the core problem well rather than accomplishing more stretch goals. The job does one thing: finds stale transfers and cancels them. I skipped features like email notifications or complex business rules, but made sure to test thoroughly and provide good tooling for demonstration.

### Implementation Notes

I included both automated scheduling (via `recurring.yml`) and manual rake tasks. The automated part handles production, while the rake tasks make it easy to demo and test during development.

### Next Steps

If I had more time, I'd add:

- Email notifications when transfers get auto-cancelled
- An admin UI for managing the job and viewing stats
- A proper audit trail for transfers
- Metrics tracking (how many transfers timeout, success rates, etc.)
- Maybe exponential backoff for transfers that keep failing
