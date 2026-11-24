# PayLink – Requirements Pack (Part A)

> Author: Member 1 (Requirements Part A). Member 2 merges this file with Part B into `docs/requirements.md`.
> Covers: Problem Summary, Stakeholders, User Stories for FR-1 → FR-25, Non-Functional Requirements, Ambiguities & Decisions (FR-15 → FR-25).

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

## 3. User Stories (FR-1 → FR-25)

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

### US-25 – Route a payment to the right biller (FR-15) · **Must**
As a customer, I want to pay electricity, water and mobile top-up bills through one unified platform so that I don't need a separate app or process for each biller.

- **Given** PayLink supports ElectroCo, AquaCo and TopUpNet, **When** a customer selects a service of one of them, **Then** the system routes the inquiry and payment to the adapter of the corresponding biller only.
- **Given** a request is sent to a biller, **When** the integration communicates with it, **Then** it uses that biller's required protocol and format (ElectroCo: REST/JSON, AquaCo: SOAP-style XML, TopUpNet: REST/JSON with callback), and the Payment Processing module never sees these details.

### US-26 – Handle each biller's way of answering (FR-15) · **Must**
As a customer, I want my payment handled correctly whether the biller answers at once, late or by callback so that I always get the right result.

- **Given** ElectroCo or AquaCo, **When** the biller replies within 10 seconds, **Then** the result (paid or refused) is returned synchronously and mapped to the payment state Completed or Failed.
- **Given** a biller does not answer within 10 seconds, **When** the timeout is reached, **Then** the payment becomes Unknown, the funds stay held, and the customer is told the payment is being processed.
- **Given** TopUpNet replies "accepted", **When** it later calls the callback URL with "success" or "failed", **Then** the payment moves to Completed or Failed accordingly, and a duplicate callback is ignored and logged.

### US-27 – One biller down does not stop the others (FR-15) · **Must**
As a customer, I want to keep paying other billers when one biller is unavailable so that a single outage does not block me.

- **Given** one biller is unavailable (for example AquaCo is down), **When** a customer pays a bill of another biller, **Then** that payment is processed normally.

### US-28 – Add a new biller without changing the core (FR-15) · **Must**
As the business, I want to add a new biller by adding only its integration and configuration so that growth does not put existing features at risk.

- **Given** a new biller needs to be added, **When** only its adapter and configuration are added, **Then** the Payment Processing, Fees, Wallet and Notifications modules remain unchanged.

### US-29 – Fixed and percentage service fees (FR-16) · **Must**
As a customer, I want the service fee to be calculated correctly for each biller and service so that I see the exact total before I pay.

- **Given** a bill for electricity or water, **When** the fee is calculated, **Then** the fee is a fixed 2.50 EGP.
- **Given** a mobile top-up of amount X, **When** the fee is calculated, **Then** the fee is 1.5% of X, rounded to 2 decimals, and not less than 1 EGP.

### US-30 – Tiered fee for internet bills (FR-16) · **Must**
As a customer, I want internet bills to use the fee tier that matches my amount so that I pay the right fee.

- **Given** an internet payment of 200 EGP or less, **When** the fee is calculated, **Then** the fee is 2 EGP.
- **Given** an internet payment of more than 200 EGP, **When** the fee is calculated, **Then** the fee is 4 EGP.

### US-31 – Promotion period fee (FR-16) · **Must**
As a customer, I want the service fee removed during a promotion so that I benefit from it.

- **Given** a promotion is configured for one biller with start and end dates, **When** a payment to that biller is made within the period, **Then** the fee is 0 EGP.
- **Given** the promotion is expired, not started, or inactive, **When** a payment is made, **Then** the normal fee applies.

### US-32 – Change fee rules and promotions without redeploying (FR-16) · **Must**
As an admin, I want to change fee rules and promotion dates in configuration so that they update without redeployment.

- **Given** an admin changes a fee rule or promotion dates, **When** the next fee is calculated, **Then** the new values apply without redeployment.

### US-33 – Agent pays on behalf of a customer (FR-17) · **Should**
As an agent, I want to pay a bill on behalf of a customer at my PayLink terminal so that customers without the app can still pay.

- **Given** an active agent with a wallet, **When** the agent submits a bill payment for a customer, **Then** the payment follows the same life cycle as a customer payment (section 2.5) and the payment record shows both the customer and the agent.
- **Given** a payment initiated by an agent, **When** the checks of FR-18 run, **Then** the single-payment and daily limits are checked against the customer's account and the customer's verification level.
- **Given** a user who is not an agent, **When** they try to pay on behalf of another customer, **Then** the request is rejected with a clear reason.

### US-34 – Agent earns commission (FR-17) · **Should**
As an agent, I want to earn commission on completed payments so that serving customers pays off.

- **Given** an agent payment completes, **When** the payment becomes Completed, **Then** the customer is charged amount + fee, and the agent's wallet is credited 40% of the service fee.
- **Given** an agent payment is Rejected, Failed or still Unknown, **When** it is in one of these states, **Then** no commission is credited, and held funds are released only on Failed.
- **Given** the same idempotency key is sent twice, **When** the second request arrives, **Then** the first result is returned and the commission is credited only once.
- **Given** a commission is credited, **When** the ledger entry is created, **Then** an audit record shows who, when and why.

### US-35 – Single payment limits (FR-18) · **Must**
As a customer, I want to be told clearly when my payment is below or above the allowed amount so that I understand why it was refused.

- **Given** a payment amount below 5 EGP or above 10,000 EGP, **When** it is submitted, **Then** it is Rejected with a reason stating the minimum and maximum allowed.
- **Given** a payment of exactly 5 EGP or exactly 10,000 EGP and within the daily limit, **When** it is submitted, **Then** it passes the single-payment check.
- **Given** a payment is Rejected because of a limit, **When** the rejection happens, **Then** no funds are held, no ledger entry is created, and an audit record is written.

### US-36 – Daily limit by verification level (FR-18) · **Must**
As a customer, I want my daily limit to match my verification level so that I know how much I can pay today.

- **Given** a basic account, **When** the daily total plus the new amount would exceed 5,000 EGP, **Then** the payment is Rejected with a reason stating the daily limit and the remaining amount available today (a 7,000 EGP payment from a basic account is rejected with the daily-limit reason).
- **Given** a verified account, **When** the daily total plus the new amount would exceed 30,000 EGP, **Then** the payment is Rejected with the same type of reason.
- **Given** a customer is upgraded from basic to verified, **When** they submit a payment, **Then** the verified daily limit applies.
- **Given** an admin changes a limit value, **When** the next payment is checked, **Then** the new value applies without redeployment.

### US-37 – How the daily total is counted (FR-18) · **Must**
As the business, I want the daily total calculated in one clear way so that limits are fair and cannot be bypassed.

- **Given** the daily total is calculated, **When** payments are counted, **Then** only the payment amount (not the fee) is counted, for payments in Completed, FundsHeld, SentToBiller and Unknown states. Failed, Refunded and Rejected payments are not counted.
- **Given** the daily limit, **When** a day is computed, **Then** the day runs from 00:00 to 23:59 Cairo time.
- **Given** a payment made by an agent for a customer, **When** the daily limit is checked, **Then** it is counted on the customer's account.

### US-38 – Block an account after too many attempts (FR-19) · **Should**
As PayLink, I want to temporarily block an account that makes too many payment attempts in a short time so that fraud and automated abuse are stopped before money is lost.

- **Given** a customer account made 5 payment attempts in the last 60 seconds, **When** a 6th attempt arrives, **Then** the payment is Rejected and the account is blocked for 10 minutes.
- **Given** payment attempts are counted, **When** the count is calculated, **Then** all attempts count, including attempts rejected by other checks (such as limits).
- **Given** several attempts from one account arrive at the same moment, **When** they are counted, **Then** the count is correct and no more than 5 are accepted in 60 seconds.
- **Given** a request is repeated with the same idempotency key, **When** the duplicate arrives, **Then** it is not counted as a new attempt.

### US-39 – Blocked account is released after 10 minutes (FR-19) · **Should**
As a customer, I want to know why I cannot pay and when I can pay again so that I am not confused.

- **Given** an account (customer or agent) is temporarily blocked, **When** it is used to submit a payment, **Then** the payment is Rejected with a reason saying the account is blocked and when it will be available again.
- **Given** 10 minutes passed since a block started, **When** the account submits a payment, **Then** the block is lifted automatically and the payment is processed normally.
- **Given** a block starts or ends, **When** it happens, **Then** an audit record is written with who, when and why.
- **Given** an admin changes the attempt count, the time window or the block duration, **When** the next attempt is checked, **Then** the new values apply without redeployment.

### US-40 – Velocity rule for agents (FR-19) · **Should**
As PayLink, I want the velocity rule to treat agents and customers fairly so that abuse is stopped without blocking normal agent work.

- **Given** an agent made more than 5 attempts within 60 seconds on the same customer account, **When** the 6th attempt arrives, **Then** the payment is Rejected and both the customer account and the agent account are blocked for 10 minutes.
- **Given** an agent made payments for 6 different customers within 60 seconds (no more than 5 on any single account), **When** the 6th payment arrives, **Then** the velocity rule does not block the agent.
- **Given** a customer's own attempts and attempts made by an agent on their account, **When** the count is calculated, **Then** all of them are added to the same counter for that customer account.
- **Given** an agent account is blocked, **When** the agent tries to pay on behalf of a customer, **Then** it is Rejected; the block does not stop other uses of the agent's own wallet.

### US-41 – Find a payment by reference (FR-20) · **Must**
As a support employee, I want to search for a payment by its reference so that I can investigate customer complaints quickly.

- **Given** a valid PayLink payment reference or the biller's reference, **When** a support employee searches for it, **Then** the system shows the payment summary: customer, agent (if any), biller, service, amount, fee, total, commission, current state and creation time.
- **Given** a reference that does not exist, **When** support searches for it, **Then** a clear "payment not found" message is returned.
- **Given** a payment of any age, **When** support searches for it, **Then** its history is returned.

### US-42 – See the full history of a payment (FR-20) · **Must**
As a support employee, I want to see everything that happened to a payment so that I can explain it accurately to the customer.

- **Given** a payment found, **When** the history is displayed, **Then** it lists every state transition (for example Initiated → FundsHeld → SentToBiller → Unknown → Completed) in time order, each with a timestamp and a reason.
- **Given** a payment found, **When** the history is displayed, **Then** it lists all related ledger entries (hold, release, final charge, fee income, commission, refund).
- **Given** a payment found, **When** the history is displayed, **Then** it shows the biller interaction: the request sent, the biller's answer, timeouts, the 1, 5 and 15 minute re-queries, and callbacks received (including duplicates that were ignored).
- **Given** a payment found, **When** the history is displayed, **Then** it shows the status of each notification (sent, retried, undelivered).
- **Given** a payment was flagged in the reconciliation report, **When** the history is displayed, **Then** the flagged difference is shown.

### US-43 – Protect payment search (FR-20) · **Must**
As PayLink, I want payment search to be restricted, read-only and logged so that customer data is protected.

- **Given** a user without a support or admin role, **When** they try to search payments by reference, **Then** the request is rejected.
- **Given** the search result, **When** support views it, **Then** it is read-only (no change to the payment from this screen).
- **Given** the result shows a phone number or meter number, **When** support views it, **Then** it is partly masked (for example 0100****567).
- **Given** a support employee searches for a payment, **When** the search is done, **Then** an audit record is written with who searched, which reference, and when.

### US-44 – Block an account (FR-21) · **Should**
As a support employee, I want to block a customer or agent account so that I can stop suspicious activity quickly.

- **Given** an active account, **When** a support employee blocks it with a reason, **Then** the account status becomes Blocked immediately.
- **Given** a block applied by support, **When** time passes, **Then** the block stays until a support employee unblocks it (it does not expire automatically).

### US-45 – Unblock an account (FR-21) · **Should**
As a support employee, I want to unblock an account so that access is restored once the problem is resolved.

- **Given** a blocked account, **When** a support employee unblocks it with a reason, **Then** the status becomes Active, any automatic velocity block is cleared, and payments are accepted again.

### US-46 – What a blocked account can and cannot do (FR-21) · **Should**
As a customer with a blocked account, I want to keep seeing my money and receive any refund so that I am never cut off from my own balance.

- **Given** a blocked customer account, **When** a payment is submitted (by the customer or by an agent for them), **Then** it is Rejected with a reason saying the account is blocked.
- **Given** a blocked agent account, **When** the agent tries to pay on behalf of a customer, **Then** it is Rejected with a clear reason.
- **Given** a blocked account, **When** the user logs in, **Then** they can view their balance and transaction history but cannot pay.
- **Given** a blocked account, **When** a top-up is submitted (by card or agent cash), **Then** it is rejected with a clear reason.
- **Given** a blocked account, **When** a hold is released or a refund is issued, **Then** the money is credited to the wallet normally.

### US-47 – Blocking is safe for payments in progress (FR-21) · **Should**
As the business, I want blocking to be safe while payments are running so that money is never left in a half-processed state.

- **Given** payments of an account are in FundsHeld, SentToBiller or Unknown, **When** the account is blocked, **Then** they continue their life cycle to a final state, and an agent's commission is still credited when such a payment completes.
- **Given** a payment arrives at the same moment the account is blocked, **When** it is processed, **Then** it is either fully rejected or fully accepted before the block, never half-processed.

### US-48 – Controlled and traceable block actions (FR-21) · **Should**
As PayLink, I want every block or unblock to need a reason, be limited to authorised staff and be communicated so that the action can be trusted.

- **Given** a block or unblock, **When** the action is done, **Then** a reason is mandatory and an audit record is written with who, when and why.
- **Given** a user who is not support or admin, **When** they try to block or unblock an account, **Then** the request is rejected.
- **Given** an account that is already blocked (or already active), **When** support blocks (or unblocks) it again, **Then** a clear message is returned and no duplicate audit record is created.
- **Given** a block or unblock, **When** the action is done, **Then** the customer is notified with a general reason and no security details.

### US-49 – Notified when a payment completes (FR-22) · **Must**
As a customer, I want an SMS and a push message when my payment completes so that I know the result without opening the app.

- **Given** a payment becomes Completed, **When** the state changes, **Then** the customer receives an SMS and a push message with the biller, amount, fee, total and payment reference.

### US-50 – Notified when a payment fails or is refunded (FR-22) · **Must**
As a customer, I want a message when my payment fails, and again when my money returns to my wallet, so that I know why and where my money is.

- **Given** a payment becomes Failed, **When** the state changes, **Then** the customer receives an SMS and a push message with a clear reason (for example the biller's refusal reason).
- **Given** a failed payment is Refunded and the held money returns to the wallet, **When** the state changes, **Then** the customer receives a separate SMS and push message with the returned amount, the payment reference and the new available balance.

### US-51 – Reliable notification rules (FR-22) · **Must**
As the business, I want notifications sent once, in the background and safely so that they never slow down or break payments.

- **Given** a payment was Unknown and later becomes Completed or Failed, **When** it reaches the final state, **Then** the customer receives the matching notification.
- **Given** a payment becomes Completed, Failed or Refunded, **When** the notification is sent, **Then** it is sent asynchronously and does not delay the payment response.
- **Given** the SMS provider is down, **When** a payment completes, **Then** the payment still completes and the push message is still sent.
- **Given** the same final state is reported twice (for example a duplicate TopUpNet callback), **When** the second report arrives, **Then** no second notification is sent.
- **Given** a notification is created, **When** the message is built, **Then** it uses a message template with placeholders and shows sensitive values (phone or meter number) partly masked.
- **Given** each notification attempt, **When** it finishes, **Then** its channel, status and time are recorded so support can see it.

### US-52 – Retry failed notifications (FR-23) · **Should**
As PayLink, I want to retry failed notifications a limited number of times and then mark them as undelivered so that temporary provider problems do not make customers miss important messages.

- **Given** an SMS, email or push send fails with a temporary error (timeout, provider down), **When** the failure is detected, **Then** the system retries it up to 3 times after the first attempt (maximum 4 attempts).
- **Given** a retry succeeds, **When** the provider accepts the message, **Then** the status becomes Sent and no more retries are made.
- **Given** the 3 retries all fail, **When** the last retry fails, **Then** the notification is marked Undelivered, no more attempts are made, no other channel is used instead, and the failure is logged.
- **Given** a permanent error (for example an invalid phone number), **When** the send fails, **Then** the notification is marked Undelivered immediately without retries.

### US-53 – Retries never harm payments (FR-23) · **Should**
As the business, I want notification failures and retries kept separate from payments so that a messaging problem never affects money.

- **Given** the SMS provider is down when a payment completes, **When** retries run, **Then** the payment stays Completed and notification failures never change a payment's state.
- **Given** one channel fails, **When** retries run, **Then** they do not delay or block the other channel.
- **Given** a retry, **When** it is attempted, **Then** it uses the same notification record (not a new one), so the customer never receives duplicates if an earlier attempt actually succeeded.
- **Given** retries run, **When** they are executed, **Then** they run in the background and do not slow down payment processing.

### US-54 – Retries are visible, configurable and restart-safe (FR-23) · **Should**
As an admin, I want retries to be visible, configurable and safe across restarts so that no notification is silently lost.

- **Given** each attempt, **When** it finishes, **Then** the attempt number, time and error are recorded and visible to support.
- **Given** the number of retries and the delay between them (starting values about 30 seconds, 2 minutes, 10 minutes), **When** an admin changes them in configuration, **Then** the new values apply without redeployment.
- **Given** the application restarts while retries are pending, **When** it starts again, **Then** pending retries continue and are not lost.

### US-55 – Edit fee rules and promotions (FR-24) · **Should**
As an admin, I want to edit fee rules and promotion settings without redeploying so that business changes apply quickly.

- **Given** an admin, **When** they edit a fee rule (fixed amount, percentage, minimum, tier threshold or tier amount) of a biller or service, **Then** the new value is saved and used for the next fee calculation without redeployment.
- **Given** an admin, **When** they change the promotion biller or its start and end dates, **Then** the new promotion applies from the next fee calculation.

### US-56 – Edit limits (FR-24) · **Should**
As an admin, I want to edit payment and daily limits without redeploying so that limits can follow business needs.

- **Given** an admin, **When** they edit a limit (minimum payment, maximum payment, daily limit for basic accounts, daily limit for verified accounts), **Then** the new value is used for the next payment check without redeployment.
- **Given** an admin lowers the daily limit below the amount a customer has already used today, **When** the customer submits a new payment, **Then** it is Rejected, and payments already made are not affected.

### US-57 – Safe configuration changes (FR-24) · **Should**
As an admin, I want configuration changes to be validated, restricted and recorded so that mistakes and misuse are prevented.

- **Given** an invalid value (negative number, minimum above maximum, basic daily limit above verified daily limit, percentage outside 0 to 100, end date before start date), **When** the admin saves it, **Then** it is rejected with a clear message and nothing is changed.
- **Given** a payment was already created (state Initiated or later), **When** an admin changes a fee or limit, **Then** that payment keeps the values it started with, and only payments created after the change use the new values.
- **Given** a user who is not an admin (including support), **When** they try to edit fees or limits, **Then** the request is rejected.
- **Given** any change, **When** it is saved, **Then** an audit record shows who changed it, when, the old value, the new value and a mandatory reason.
- **Given** two admins edit the same value at the same time, **When** the second one saves, **Then** they get a conflict message instead of silently overwriting the first change.
- **Given** fee and limit values, **When** the system starts for the first time, **Then** the initial values come from section 2.6 of the brief and are stored as configuration, not hard-coded in the business logic.

### US-58 – Audit every money movement (FR-25) · **Must**
As an auditor or manager, I want every money movement recorded in an audit log so that any balance can be traced to who did it, when and why.

- **Given** any money movement (hold, release, final charge, fee income, commission, top-up, refund), **When** it happens, **Then** an audit record is written with the actor (customer, agent, support, admin or system), time, amount, accounts involved, the payment reference and the reason.
- **Given** a money movement creates a ledger entry, **When** the audit record is written, **Then** it references that ledger entry, and every ledger entry has exactly one matching audit record.
- **Given** a money movement, **When** it is saved, **Then** the balance change, the ledger entry and the audit record are saved in the same transaction: all of them are saved or none (100% coverage target).

### US-59 – Audit admin, support and system actions (FR-25) · **Must**
As an auditor or manager, I want every admin, support and system action recorded so that any decision can be traced.

- **Given** an admin action (add, edit or disable a biller or service, change a fee, limit or other configuration), **When** it is saved, **Then** an audit record shows who, when, what changed (old and new value) and the reason.
- **Given** a support action (block, unblock, payment search, refund approval), **When** it is done, **Then** an audit record is written with who, when and why.
- **Given** a system-triggered event (TopUpNet callback, re-query, reconciliation, velocity block start or end), **When** it happens, **Then** an audit record is written with actor system and the trigger.

### US-60 – Audit rejections, duplicates and denied attempts (FR-25) · **Must**
As an auditor or manager, I want events that move no money also recorded so that suspicious behaviour is visible.

- **Given** a payment is Rejected by a limit or fraud rule, **When** the rejection happens, **Then** an audit record is written even though no money moved.
- **Given** a duplicate request or duplicate callback is ignored, **When** it is detected, **Then** an audit record logs the ignored duplicate and no money movement is created.
- **Given** a user without the required role tries an admin or support action, **When** the request is denied, **Then** the denied attempt is logged with who, what and when.

### US-61 – Protect and search the audit log (FR-25) · **Must**
As an auditor or manager, I want the audit log to be tamper-proof, searchable and free of secrets so that I can trust it.

- **Given** an audit record, **When** it is saved, **Then** it can never be edited or deleted through the application or the API; a correction is a new record that refers to the old one.
- **Given** an authorized admin, **When** they open the audit log, **Then** they can filter by account, payment reference, actor, action type and date range.
- **Given** an audit record, **When** it is saved, **Then** it never contains passwords, tokens or full card numbers, and phone or meter numbers are partly masked.
- **Given** timestamps in audit records, **When** they are stored, **Then** they are in UTC with milliseconds and shown in Cairo time to users.

---

## 4. Traceability

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
| FR-15 | Must | US-25, US-26, US-27, US-28 |
| FR-16 | Must | US-29, US-30, US-31, US-32 |
| FR-17 | Should | US-33, US-34 |
| FR-18 | Must | US-35, US-36, US-37 |
| FR-19 | Should | US-38, US-39, US-40 |
| FR-20 | Must | US-41, US-42, US-43 |
| FR-21 | Should | US-44, US-45, US-46, US-47, US-48 |
| FR-22 | Must | US-49, US-50, US-51 |
| FR-23 | Should | US-52, US-53, US-54 |
| FR-24 | Should | US-55, US-56, US-57 |
| FR-25 | Must | US-58, US-59, US-60, US-61 |

## 5. Non-Functional Requirements

Six measurable requirements taken from the quality table in section 3.3 of the brief. Every one has a target number and a way to measure it.

| ID | Quality | Requirement | Target | How we measure | Priority | Related |
|---|---|---|---|---|---|---|
| NFR-1 | Correctness | The system never charges a payment twice and never lets a wallet balance go negative, even with duplicate or simultaneous requests. | **0 double charges** and **0 negative balances** in all duplicate and concurrency tests; every wallet balance equals the sum of its ledger entries. | Automated tests: for example 100 parallel requests with the same idempotency key give exactly 1 charge; 50 parallel payments on a balance that covers only one give exactly 1 success. After each test a check compares every balance with its ledger sum. | Must | US-08, US-09, US-17, US-35 → US-37; hard cases #1, #4, #6 |
| NFR-2 | Performance | The system handles the busiest day of the month. | **100 payments per second sustained for 1 minute** (6,000 payments) against the mock billers, with an error rate below 1%. | Load test (for example k6 or JMeter) run in the pipeline or documented run; the report shows the measured rate and error rate. | Must | US-15, US-38 (the velocity check must stay fast) |
| NFR-3 | Resilience | A problem at one biller does not stop payments to other billers. | While the AquaCo mock fails or times out on every request, **100% of ElectroCo and TopUpNet test payments still complete** normally. | Integration test using the mock server's fail-on-purpose mode; a slow biller must not block the threads or queues used by the others. | Must | US-26, US-27; hard cases #2, #3 |
| NFR-4 | Modifiability | A new biller is added without changing the rest of the system. | Adding a biller (or the ElectroCo v2 change) changes **0 files outside the Biller Integration module and configuration**. | `git diff` of the change shows only integration and configuration files; this proof goes in the report. | Must | US-28; hard case #8; ElectroCo v2 |
| NFR-5 | Auditability | Every money movement and admin action can be traced. | **100% of money movements and admin actions** have an audit record with who, when and why; **0 ledger entries** without a matching audit record. | Automated test after the test suite: count ledger entries versus audit records and check that actor, time and reason are never empty. | Must | US-08, US-57 → US-61 |
| NFR-6 | Testability | The business logic is covered by automated tests. | **At least 70% line coverage on domain logic**, measured in CI, and one automated test for each of the 8 hard cases. | The CI pipeline reports coverage on every push and fails below 70%. | Must | Section 2.7 of the brief, CI pipeline |

> The error rate below 1% in NFR-2 is a team choice. The brief fixes only the 100 payments per second target.

## 6. Ambiguities & Decisions (FR-15 → FR-25)

**Status:** *Decided* = the team decided or accepted it explicitly. *Assumed* = written into the stories as an assumption but not confirmed yet. *Open* = no decision yet.

| # | Related | Ambiguity / Question | Decision | Status |
|---|---|---|---|---|
| 1 | FR-15 | Is NetCo (daily batch CSV) in scope? | Optional in the brief: kept as a Could, not part of the minimum scope. | Assumed |
| 2 | FR-16, US-30 | Is exactly 200 EGP in the 2 EGP tier or the 4 EGP tier? | The 2 EGP tier ("up to 200" in the brief). | Decided (brief) |
| 3 | FR-16, US-29 | How is the 1.5% mobile fee rounded? | Exact decimal, 2 decimals, minimum 1 EGP. The rounding mode (for example half-up) is chosen in the design. | Assumed |
| 4 | FR-16, US-31 | Are the promotion start and end dates included in the period? | Proposed: both dates are included (inclusive). | **Open** |
| 5 | FR-17, US-34 | When an agent pays for a customer, whose wallet is charged? | The customer's wallet (as written in US-34). The alternative is the agent's wallet, because the agent received cash. | **Open** |
| 6 | FR-17, FR-18, US-33, US-37 | Does an agent payment count against the customer's or the agent's daily limit? | The customer's account. | Decided |
| 7 | FR-18, US-37 | Does the daily limit count the amount only, or amount + fee? | Amount only. | Decided |
| 8 | FR-18, US-37 | Which payments count toward the daily total? | Completed, FundsHeld, SentToBiller and Unknown. Failed, Refunded and Rejected do not count. | Decided |
| 9 | FR-18, US-37 | When does "today" start? | 00:00 Cairo time. | Decided |
| 10 | FR-18, US-36 | A basic account tries to pay 7,000 EGP. | Rejected: a basic account can never exceed 5,000 EGP per day; the reason shown is the daily limit. | Decided |
| 11 | FR-19, US-38 | Which attempts count in the 60 seconds? | All attempts, including rejected ones. | Decided |
| 12 | FR-19, US-40 | Who gets blocked when an agent pays for a customer? | The customer account; the agent too if the agent repeats more than 5 attempts on the same account. | Decided |
| 13 | FR-19, US-40 | An agent pays for 6 different customers in 60 seconds. | Not blocked: the rule applies to repeats on the same account. | Decided |
| 14 | FR-19, US-40 | Is a customer's own attempts counter shared with agent attempts? | Yes, one counter per customer account. | Decided |
| 15 | FR-19, US-38 | Is a repeated request with the same idempotency key counted? | No, it is not a new attempt. | Decided |
| 16 | FR-19, US-40, US-46 | What does an agent block stop? | Paying on behalf of customers only, not the agent's own wallet. | Decided |
| 17 | FR-19, US-38 | Fixed or sliding 60-second window? | Sliding window. | Assumed |
| 18 | FR-19, US-39 | Is the customer notified when an automatic block starts? | Yes (linked to FR-22). No acceptance criterion written yet. | Assumed |
| 19 | FR-20, US-41 | What is "reference"? | The PayLink payment reference; the biller reference is also searchable. | Decided |
| 20 | FR-20, US-43 | Are phone and meter numbers masked for support? | Yes, partly masked (for example 0100****567). | Decided |
| 21 | FR-20, US-43 | Is a support search written to the audit log? | Yes. | Decided |
| 22 | FR-20, US-41 | Can support search payments of any age? | Yes. | Decided |
| 23 | FR-21, US-46 | What can a blocked account do? | Log in and view balance and history; cannot pay or top up. | Decided |
| 24 | FR-21, US-47 | What happens to payments in progress when an account is blocked? | They continue to a final state; the agent's commission is still credited on completion. | Decided |
| 25 | FR-21, US-45 | Does a manual unblock also clear an automatic velocity block? | Yes. | Decided |
| 26 | FR-21, US-48 | Is the customer notified of a block or unblock? | Yes, with a general reason and no security details. | Decided |
| 27 | FR-21, US-46 | Can a refund or hold release reach a blocked wallet? | Yes, the money is credited normally. | Decided |
| 28 | FR-22, US-50 | Is there a separate message when a failed payment is Refunded? | Yes, in addition to the Failed message. | Decided |
| 29 | FR-22 | Message language and customer opt-out of notifications. | Removed from scope: not required. | Decided |
| 30 | FR-22 | Are Unknown and Rejected payments notified by SMS/push? | No: the customer is told in the API response only. | Assumed |
| 31 | FR-22 | Who is notified when an agent pays for a customer? | The customer (SMS + push) and the agent (push only). No acceptance criterion written yet. | Assumed |
| 32 | FR-23, US-52 | How many attempts? | First attempt + 3 retries (4 at most). | Decided |
| 33 | FR-23, US-54 | What is the delay between retries? | Configurable; starting values about 30 seconds, 2 minutes, 10 minutes. | Decided |
| 34 | FR-23, US-52 | Which channels are retried? | SMS, email and push, with the same rule. | Decided |
| 35 | FR-23, US-52 | Are permanent errors (for example an invalid number) retried? | No, they are marked Undelivered immediately. | Decided |
| 36 | FR-23, US-52 | Is another channel used when a notification is Undelivered? | No fallback; it is only logged. | Decided |
| 37 | FR-24, US-55 → US-57 | Which values can an admin edit? | Fees and limits at minimum; all values of section 2.6 of the brief live in configuration (velocity, retries, timeout, commission). Acceptance criteria cover fees, limits and promotions only. | Assumed |
| 38 | FR-24, US-57 | An admin changes a fee between a customer's inquiry and the payment. | The new fee applies and the response shows the total actually charged. No acceptance criterion written yet. | Assumed |
| 39 | FR-24 | Scheduled changes or a second admin's approval? | No: changes apply at once and the audit log is enough (promotion dates are the only scheduled value). | Assumed |
| 40 | FR-25, US-58 | Ledger versus audit log. | Two separate tables; the audit record points to the ledger entry id. | **Open** (proposed) |
| 41 | FR-25, US-59 | Which read actions are audited? | Support payment search only. | **Open** (proposed) |
| 42 | FR-25, US-61 | Who can read the audit log? | Admin only. | **Open** (proposed) |
| 43 | FR-25, US-61 | Protection against tampering (for example a hash chain)? | Append-only is enough; a hash chain is a Could. | **Open** (proposed) |
| 44 | FR-25 | How long are audit records kept? | Never deleted within the project. | **Open** (proposed) |

> FR-26 → FR-28 continue numbering from **US-62**.
