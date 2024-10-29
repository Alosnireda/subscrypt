;; CreatorPass Subscription Token Contract - Production Version
;; Implementation of SIP-009 with subscription management features
;; Version: 1.0.0
;; Security Contact: security@creatorpass.com

;; SIP-009 Interface Implementation
(impl-trait .sip-009-trait.nft-trait)

;; Constants and Error Codes
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-PAUSED (err u402))
(define-constant ERR-INVALID-TIER (err u403))
(define-constant ERR-TOKEN-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-EXISTS (err u405))
(define-constant ERR-INVALID-AMOUNT (err u406))
(define-constant ERR-BLACKLISTED (err u407))
(define-constant ERR-RATE-LIMIT (err u408))
(define-constant ERR-EXPIRED (err u409))
(define-constant ERR-OVERFLOW (err u410))
(define-constant ERR-REENTRANCY (err u411))

;; Data Variables
(define-data-var contract-paused bool false)
(define-data-var total-supply uint u0)
(define-data-var last-token-id uint u0)
(define-data-var mint-rate-limit uint u100) ;; Max mints per block
(define-data-var current-block-mints uint u0)
(define-data-var last-mint-block uint u0)
(define-data-var reentrancy-guard uint u0)

;; Administrative Data Maps
(define-map administrators principal bool)
(define-map blacklisted-users principal bool)
(define-map emergency-admins principal bool)

;; Token Data Maps
(define-map tokens
    uint
    {
        owner: principal,
        tier: uint,
        expires-at: uint,
        auto-renewal: bool,
        last-modified: uint,
        metadata-uri: (string-ascii 256)
    }
)

(define-map token-owners
    uint
    principal
)

(define-map tier-prices
    uint
    {
        price: uint,
        early-renewal-discount: uint,
        features: (string-ascii 256)
    }
)

(define-map user-subscriptions
    principal
    {
        active-tokens: (list 10 uint),
        total-spent: uint,
        join-date: uint,
        last-renewal: uint
    }
)

;; Reentrancy Guard
(define-private (begin-atomic)
    (begin
        (asserts! (is-eq (var-get reentrancy-guard) u0) ERR-REENTRANCY)
        (var-set reentrancy-guard u1)
        (ok true)
    )
)

(define-private (end-atomic)
    (begin
        (var-set reentrancy-guard u0)
        (ok true)
    )
)

;; Authorization Checks
(define-private (is-administrator)
    (or 
        (is-eq tx-sender CONTRACT-OWNER)
        (default-to false (map-get? administrators tx-sender))
    )
)

(define-private (is-emergency-admin)
    (or
        (is-eq tx-sender CONTRACT-OWNER)
        (default-to false (map-get? emergency-admins tx-sender))
    )
)

;; Rate Limiting
(define-private (check-rate-limit)
    (let (
        (current-block (unwrap-panic (get-block-info? id u0)))
    )
        (if (is-eq (var-get last-mint-block) current-block)
            (if (< (var-get current-block-mints) (var-get mint-rate-limit))
                (begin
                    (var-set current-block-mints (+ (var-get current-block-mints) u1))
                    (ok true)
                )
                ERR-RATE-LIMIT
            )
            (begin
                (var-set last-mint-block current-block)
                (var-set current-block-mints u1)
                (ok true)
            )
        )
    )
)

;; Administrative Functions
(define-public (set-administrator (admin principal) (status bool))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (map-set administrators admin status)
        (print {event: "admin-status-change", admin: admin, status: status})
        (ok true)
    )
)

(define-public (set-emergency-admin (admin principal) (status bool))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (map-set emergency-admins admin status)
        (print {event: "emergency-admin-change", admin: admin, status: status})
        (ok true)
    )
)

(define-public (pause-contract)
    (begin
        (asserts! (is-emergency-admin) ERR-NOT-AUTHORIZED)
        (var-set contract-paused true)
        (print {event: "contract-paused", admin: tx-sender})
        (ok true)
    )
)

(define-public (unpause-contract)
    (begin
        (asserts! (is-emergency-admin) ERR-NOT-AUTHORIZED)
        (var-set contract-paused false)
        (print {event: "contract-unpaused", admin: tx-sender})
        (ok true)
    )
)

;; Subscription Management Functions
(define-public (mint-subscription (tier uint))
    (let (
        (new-token-id (+ (var-get last-token-id) u1))
        (tier-info (unwrap! (map-get? tier-prices tier) ERR-INVALID-TIER))
        (current-time (unwrap-panic (get-block-info? time u0)))
    )
        (try! (begin-atomic))
        (asserts! (not (var-get contract-paused)) ERR-PAUSED)
        (asserts! (not (default-to false (map-get? blacklisted-users tx-sender))) ERR-BLACKLISTED)
        (try! (check-rate-limit))

        ;; Payment processing
        (try! (contract-call? .token-trait transfer 
            (get price tier-info) 
            tx-sender 
            (as-contract tx-sender)
        ))

        ;; Token creation
        (map-set tokens new-token-id {
            owner: tx-sender,
            tier: tier,
            expires-at: (+ current-time u2592000), ;; 30 days
            auto-renewal: false,
            last-modified: current-time,
            metadata-uri: (concat "ipfs://creatorpass/" (uint-to-string new-token-id))
        })

        ;; Update state
        (map-set token-owners new-token-id tx-sender)
        (var-set last-token-id new-token-id)
        (var-set total-supply (+ (var-get total-supply) u1))

        ;; Update user subscriptions
        (let (
            (user-sub (default-to 
                {
                    active-tokens: (list new-token-id),
                    total-spent: (get price tier-info),
                    join-date: current-time,
                    last-renewal: current-time
                }
                (map-get? user-subscriptions tx-sender)
            ))
        )
            (map-set user-subscriptions tx-sender user-sub)
        )

        (print {
            event: "subscription-minted",
            token-id: new-token-id,
            owner: tx-sender,
            tier: tier
        })

        (try! (end-atomic))
        (ok new-token-id)
    )
)

;; Token Upgrade/Downgrade
(define-public (change-subscription-tier (token-id uint) (new-tier uint))
    (let (
        (token (unwrap! (map-get? tokens token-id) ERR-TOKEN-NOT-FOUND))
        (current-tier-info (unwrap! (map-get? tier-prices (get tier token)) ERR-INVALID-TIER))
        (new-tier-info (unwrap! (map-get? tier-prices new-tier) ERR-INVALID-TIER))
        (current-time (unwrap-panic (get-block-info? time u0)))
    )
        (try! (begin-atomic))
        (asserts! (not (var-get contract-paused)) ERR-PAUSED)
        (asserts! (is-eq tx-sender (get owner token)) ERR-NOT-AUTHORIZED)

        ;; Handle price difference
        (if (> (get price new-tier-info) (get price current-tier-info))
            (try! (contract-call? .token-trait transfer 
                (- (get price new-tier-info) (get price current-tier-info))
                tx-sender 
                (as-contract tx-sender)
            ))
            (try! (contract-call? .token-trait transfer 
                (- (get price current-tier-info) (get price new-tier-info))
                (as-contract tx-sender)
                tx-sender
            ))
        )

        ;; Update token
        (map-set tokens token-id (merge token {
            tier: new-tier,
            last-modified: current-time
        }))

        (print {
            event: "subscription-tier-changed",
            token-id: token-id,
            old-tier: (get tier token),
            new-tier: new-tier
        })

        (try! (end-atomic))
        (ok true)
    )
)

;; Refund Processing
(define-public (process-refund (token-id uint))
    (let (
        (token (unwrap! (map-get? tokens token-id) ERR-TOKEN-NOT-FOUND))
        (tier-info (unwrap! (map-get? tier-prices (get tier token)) ERR-INVALID-TIER))
        (current-time (unwrap-panic (get-block-info? time u0)))
        (remaining-time (- (get expires-at token) current-time))
        (total-period u2592000) ;; 30 days in seconds
        (refund-amount (/ (* (get price tier-info) remaining-time) total-period))
    )
        (try! (begin-atomic))
        (asserts! (is-administrator) ERR-NOT-AUTHORIZED)
        (asserts! (> remaining-time u0) ERR-EXPIRED)

        ;; Process refund
        (try! (contract-call? .token-trait transfer 
            refund-amount
            (as-contract tx-sender)
            (get owner token)
        ))

        ;; Burn token
        (try! (burn-token token-id))

        (print {
            event: "refund-processed",
            token-id: token-id,
            amount: refund-amount,
            recipient: (get owner token)
        })

        (try! (end-atomic))
        (ok refund-amount)
    )
)

;; Batch Operations
(define-public (batch-burn-expired)
    (let (
        (current-time (unwrap-panic (get-block-info? time u0)))
    )
        (try! (begin-atomic))
        (asserts! (is-administrator) ERR-NOT-AUTHORIZED)

        ;; Implementation would iterate through tokens and burn expired ones
        ;; Note: Actual implementation would need to be done through multiple transactions
        ;; due to block gas limits

        (try! (end-atomic))
        (ok true)
    )
)

;; Read-Only Functions
(define-read-only (get-token-details (token-id uint))
    (ok (map-get? tokens token-id))
)

(define-read-only (get-subscription-status (account principal))
    (ok (map-get? user-subscriptions account))
)

(define-read-only (is-subscription-active (token-id uint))
    (let (
        (token (unwrap! (map-get? tokens token-id) ERR-TOKEN-NOT-FOUND))
        (current-time (unwrap-panic (get-block-info? time u0)))
    )
        (ok (and
            (not (var-get contract-paused))
            (not (default-to false (map-get? blacklisted-users (get owner token))))
            (< current-time (get expires-at token))
        ))
    )
)

;; Required by SIP-009
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (err u500) ;; Transfers not allowed for subscription tokens
)

(define-read-only (get-owner (token-id uint))
    (ok (map-get? token-owners token-id))
)

(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)

;; Events
(define-data-var events-enabled bool true)

(define-private (emit-event (name (string-ascii 50)) (data (buff 256)))
    (if (var-get events-enabled)
        (print {event-name: name, event-data: data})
        true
    )
)