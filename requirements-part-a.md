# PayLink – Requirements Pack (Part A)

> Covers: Problem Summary, Stakeholders, User Stories for FR-1 → FR-14.

## 1. Problem Summary

PayLink is an Egyptian bill-payment company (similar to Fawry or Vodafone Cash). Customers pay utility bills (electricity, water, mobile top-up, internet) from a digital wallet, through the mobile app or through agents (small shops with a PayLink terminal). Billers (utility companies) want to be paid quickly and correctly.

PayLink earns money from a small **service fee** per payment and pays **commission** to agents. Because it holds customers' money, a double charge or a charge for a payment the biller never received means lost trust, lost money and possible regulator problems.

We are building a **backend** (C# / .NET) that must:

- keep money correct: every balance is the sum of ledger entries, with exact decimal arithmetic, a held balance, and no negative balances;
- run each payment through a strict life cycle (Initiated → FundsHeld → SentToBiller → Completed / Failed / Unknown → Refunded / Rejected);
- integrate with billers that behave differently (REST/JSON, SOAP-style XML, asynchronous callback, daily batch file) and stay correct when they are slow, fail or answer twice;
- be easy to extend with new billers by adding only an integration and configuration;
- support the busiest day of the month (target: 100 payments/second for 1 minute).

Business numbers (limits, fees, timeouts, retries) are fixed by the brief and must live in configuration, not in code.

## 2. Stakeholders

| Stakeholder | Role | Main interest |
|---|---|---|
| Customer | Registers, tops up, pays bills | Fast, correct payments; no double charge; clear messages on failure |
| Agent | Pays on behalf of customers at a shop terminal | Reliable payments; commission credited on completion |
| Biller (ElectroCo, AquaCo, TopUpNet, NetCo) | Issues bills and receives payments | Paid correctly; matching settlement records |
| Admin | Manages billers, services, fees, limits | Change configuration without redeploying; audit trail |
| Support employee | Investigates payments and accounts | Search by reference, full history, block/unblock accounts |
| PayLink management | Owns the business | Revenue from fees, low losses, scalability |
| Regulator / Auditor | Oversees handling of customer money | Complete audit log, traceable money movements |
| Development team and TAs | Build and grade the system | Clean modular design, tests, CI/CD |
| Notification providers (SMS, email, push) | External services | Messages sent; failures must not break payments |

## 3. User Stories (FR-1 → FR-14)

Format: *As a … I want … so that …*. Acceptance criteria are Given / When / Then.
Priority follows the brief (Must / Should / Could).

---

### US-01 – Register a customer (FR-1) · **Must**
As a new customer, I want to register so that I can use PayLink.

- **Given** valid name, phone number and password, **When** I register, **Then** an account and an empty wallet (available 0.00, held 0.00 EGP) are created and my verification level is **Basic**.
- **Given** a registered phone number, **When** someone registers again with it, **Then** the system rejects it with a clear "already registered" error and creates nothing.
- **Given** missing or invalid fields, **When** I register, **Then** the system returns validation errors per field.

### US-02 – Basic level limits applied from the start (FR-1) · **Must**
As a basic customer, I want my limits to be known so that I understand what I can pay.

- **Given** a newly registered customer, **When** I view my profile, **Then** it shows level Basic and a daily limit of 5,000 EGP (value read from configuration).

### US-03 – Upgrade to verified (FR-2) · **Should**
As a customer, I want to be upgraded to Verified so that my limits are higher.

- **Given** a Basic customer with a verification request approved, **When** the upgrade is applied, **Then** the level becomes Verified and the daily limit becomes 30,000 EGP.
- **Given** a Verified customer, **When** I request an upgrade again, **Then** the system answers that I am already verified and changes nothing.
- **Given** an upgrade, **When** it is applied, **Then** an audit record (who, when, why) is written.

### US-04 – View wallet balance (FR-3) · **Must**
As a customer, I want to see my available and held balance so that I know what I can spend.

- **Given** a wallet with ledger entries, **When** I request my balance, **Then** I see available and held amounts, both computed from the ledger.
- **Given** a payment in FundsHeld, **When** I view my balance, **Then** the held amount is included in held and excluded from available.

### US-05 – View transaction history (FR-3) · **Must**
As a customer, I want to see my transaction history so that I can check my payments.

- **Given** several ledger entries, **When** I request history, **Then** I get them newest first with date, type, amount and related payment reference.
- **Given** a large history, **When** I request a page, **Then** the system returns paged results.
- **Given** I am logged in, **When** I request history, **Then** I only see my own entries.

### US-06 – Top up by card (FR-4) · **Must**
As a customer, I want to top up my wallet with a (simulated) card so that I have funds to pay bills.

- **Given** a valid simulated card and an amount greater than 0, **When** I top up, **Then** a credit ledger entry is created and my available balance increases by exactly that amount.
- **Given** a declined simulated card, **When** I top up, **Then** the balance is unchanged and I get a clear reason.

### US-07 – Top up with agent cash (FR-4) · **Must**
As an agent, I want to top up a customer's wallet with cash so that customers without cards can use PayLink.

- **Given** an active agent and an existing customer, **When** the agent submits a cash top-up, **Then** the customer's wallet is credited and the entry records the agent as the source.
- **Given** an unknown customer, **When** the agent submits a top-up, **Then** it is rejected and no ledger entry is created.

### US-08 – Ledger entry for every balance change (FR-5) · **Must**
As the business, I want every money movement recorded in the ledger so that nothing changes silently.

- **Given** any top-up, hold, charge, release, refund, fee or commission, **When** it happens, **Then** exactly one ledger entry is created with amount, type, wallet, payment reference and timestamp.
- **Given** an existing ledger entry, **When** anyone tries to edit or delete it, **Then** the system refuses (ledger is append-only; corrections are new entries).

### US-09 – Balance computed from the ledger (FR-5) · **Must**
As an auditor, I want balances derived from ledger entries so that totals can always be proven.

- **Given** a wallet, **When** the balance is read, **Then** it equals the sum of the wallet's ledger entries.
- **Given** no code path, **When** the system runs, **Then** no balance is ever written directly (verified by tests).
- **Given** monetary values, **When** they are stored or calculated, **Then** exact decimal types are used (never floating point).

### US-10 – Manage billers and services (FR-6) · **Must**
As an admin, I want to add and edit billers and services so that the catalog stays current.

- **Given** valid biller data (name, service type, required input fields, min and max amount), **When** I add a biller or service, **Then** it is saved and appears in the catalog.
- **Given** an existing biller, **When** I edit its data, **Then** changes apply to new payments only.
- **Given** any admin change, **When** it is saved, **Then** an audit record is written.

### US-11 – Disable a biller (FR-6) · **Must**
As an admin, I want to disable a biller so that customers cannot pay it during problems.

- **Given** an active biller, **When** I disable it, **Then** it disappears from the customer list and new payments to it are rejected with a clear reason.
- **Given** a disabled biller, **When** payments to other billers are made, **Then** they work normally.
- **Given** payments already in progress for that biller, **When** I disable it, **Then** they continue their life cycle.

### US-12 – See billers and required fields (FR-7) · **Must**
As a customer, I want to see the billers and what I must enter so that I can start a payment.

- **Given** active billers, **When** I request the list, **Then** I see each biller, its services and its required input fields (for example meter number, phone number).
- **Given** a disabled biller, **When** I request the list, **Then** it is not shown.

### US-13 – Bill inquiry with fee and total (FR-8) · **Must**
As a customer, I want to see the amount, fee and total before paying so that there are no surprises.

- **Given** an active biller and a valid meter number, **When** I run an inquiry, **Then** I see the bill amount, the service fee (per fee rules) and the total (e.g., 350.00 + 2.50 = 352.50 EGP).
- **Given** a promotion period for that biller, **When** I run an inquiry, **Then** the fee shown is 0.00.
- **Given** an inquiry, **When** it completes, **Then** no money is moved and no ledger entry is created.

### US-14 – Inquiry errors handled (FR-8) · **Must**
As a customer, I want clear messages when an inquiry fails so that I know what to do.

- **Given** an unknown meter number, **When** I run an inquiry, **Then** I get a "no bill found" message.
- **Given** a biller that does not answer in time, **When** I run an inquiry, **Then** I get a "biller unavailable, try later" message and the system stays stable.

### US-15 – Pay a bill from the wallet (FR-9) · **Must**
As a customer, I want to pay a bill from my wallet so that I do not have to queue.

- **Given** sufficient funds, valid input, and passing checks, **When** I pay, **Then** the payment is created with a unique reference and moves through the life cycle until the biller's answer.
- **Given** the biller confirms, **When** the payment completes, **Then** the hold becomes a final charge and the fee is credited to PayLink income.
- **Given** an amount below 5 or above 10,000 EGP, **When** I pay, **Then** it is rejected with the reason.

### US-16 – Insufficient funds rejected (FR-9) · **Must**
As a customer, I want to be told if I lack funds so that I can top up.

- **Given** a wallet that cannot cover amount plus fee, **When** I pay, **Then** the payment becomes Rejected, no hold is created and the reason is "insufficient funds".

### US-17 – Idempotent payment requests (FR-10) · **Must**
As a customer on a slow network, I want repeated requests to be safe so that I am not charged twice.

- **Given** a payment request with idempotency key K already processed, **When** the same request with K arrives again, **Then** the system returns the original result and creates no new payment or ledger entry.
- **Given** two requests with K arriving at the same moment, **When** they are processed, **Then** only one payment is created.
- **Given** the same key K with a different payload, **When** it arrives, **Then** the system rejects it as a conflict.

### US-18 – Enforce the payment life cycle (FR-11) · **Must**
As the business, I want only valid state transitions so that payments are never in an impossible state.

- **Given** a payment in Initiated, **When** checks pass and funds are available, **Then** it moves to FundsHeld; **When** checks fail or funds are insufficient, **Then** it moves to Rejected.
- **Given** SentToBiller, **When** the biller confirms, refuses, or times out, **Then** it moves to Completed, Failed or Unknown respectively.
- **Given** Unknown, **When** the biller later confirms, **Then** Completed; **When** the biller later refuses or reconciliation finds no payment, **Then** Failed. Failed moves to Refunded after the hold is released.
- **Given** any transition not in the allowed list (e.g., Completed → Failed), **When** it is attempted, **Then** it is refused and the state is unchanged.
- **Given** Completed, Rejected or Refunded, **When** any change is attempted, **Then** it is refused (final states).

### US-19 – Hold funds before calling the biller (FR-12) · **Must**
As the business, I want money held before the biller is called so that we never promise money we do not have.

- **Given** a payment passing checks, **When** funds are held, **Then** amount + fee moves from available to held via ledger entries **before** any request is sent to the biller.
- **Given** the hold fails, **When** the payment is processed, **Then** the biller is never called.

### US-20 – Release the hold on failure (FR-12) · **Must**
As a customer, I want my money back if the payment fails so that I am not charged for nothing.

- **Given** a payment that became Failed, **When** it is processed, **Then** the held amount returns to my available balance, the payment becomes Refunded, and I receive a message with a clear reason.
- **Given** a payment in Unknown, **When** time passes, **Then** the hold is **not** released automatically; it is released only once the biller is confirmed not to have received it.

### US-21 – Timeout becomes Unknown (FR-13) · **Must**
As a customer, I want to be told my payment is being processed when the biller is slow so that I do not pay again.

- **Given** a biller that does not answer within the configured timeout (10 seconds), **When** the timeout passes, **Then** the payment becomes Unknown, money stays held, and I am told it is being processed.

### US-22 – Re-query Unknown payments (FR-13) · **Must**
As the business, I want Unknown payments re-queried automatically so that most are resolved without manual work.

- **Given** a payment in Unknown, **When** 1, 5 and 15 minutes pass (configurable), **Then** the system re-queries the biller after each interval.
- **Given** a re-query returns a final answer, **When** it arrives, **Then** the payment moves to Completed or Failed as defined by the life cycle.
- **Given** all three re-queries are unanswered, **When** the last one fails, **Then** the payment waits for reconciliation and stays Unknown.

### US-23 – Accept TopUpNet callbacks (FR-14) · **Must**
As the business, I want to accept asynchronous callbacks so that mobile top-ups complete when TopUpNet answers.

- **Given** a TopUpNet payment in SentToBiller (replied "accepted"), **When** the callback says "success", **Then** the payment becomes Completed; **When** it says "failed", **Then** Failed.
- **Given** a callback with an unknown payment reference, **When** it arrives, **Then** it is rejected and logged.

### US-24 – Ignore duplicate callbacks (FR-14) · **Must**
As the business, I want duplicate callbacks ignored so that a payment completes only once.

- **Given** a Completed payment, **When** a second "success" callback arrives, **Then** the payment is unchanged, no new ledger entries are created, and the duplicate is logged.

---

## 4. Traceability (Part A)

| FR | Priority | User stories |
|---|---|---|
| FR-1 | Must | US-01, US-02 |
| FR-2 | Should | US-03 |
| FR-3 | Must | US-04, US-05 |
| FR-4 | Must | US-06, US-07 |
| FR-5 | Must | US-08, US-09 |
| FR-6 | Must | US-10, US-11 |
| FR-7 | Must | US-12 |
| FR-8 | Must | US-13, US-14 |
| FR-9 | Must | US-15, US-16 |
| FR-10 | Must | US-17 |
| FR-11 | Must | US-18 |
| FR-12 | Must | US-19, US-20 |
| FR-13 | Must | US-21, US-22 |
| FR-14 | Must | US-23, US-24 |

> Member 2 continues numbering from **US-25** for FR-15 → FR-28.
