;; CreatorPass Subscription Token Contract
;; Version: 1.0.0

;; Define traits
(define-trait sip009-nft-trait
    (
        (get-last-token-id () (response uint uint))
        (get-token-uri (uint) (response (optional (string-ascii 256)) uint))
        (get-owner (uint) (response (optional principal) uint))
        (transfer (uint principal principal) (response bool uint))
    )
)

(define-trait ft-trait
    (
        (transfer (uint principal principal) (response bool uint))
        (get-balance (principal) (response uint uint))
    )
)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-PAUSED (err u402))
(define-constant ERR-INVALID-TIER (err u403))
(define-constant ERR-TOKEN-NOT-FOUND (err u404))
(define-constant ERR-REENTRANCY (err u405))

;; Data Variables
(define-data-var contract-paused bool false)
(define-data-var total-supply uint u0)
(define-data-var last-token-id uint u0)
(define-data-var reentrancy-guard uint u0)

;; Maps
(define-map administrators principal bool)
(define-map tokens
    uint
    {
        owner: principal,
        tier: uint,
        expires-at: uint,
        metadata-uri: (string-ascii 256)
    }
)

(define-map token-owners uint principal)

(define-map tier-prices
    uint
    {
        price: uint,
        features: (string-ascii 256)
    }
)

;; Helper Functions
(define-private (get-token-id-string (token-id uint))
    (unwrap-panic (element-at 
        (list 
            "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10"
            "11" "12" "13" "14" "15" "16" "17" "18" "19" "20"
            "21" "22" "23" "24" "25" "26" "27" "28" "29" "30"
            "31" "32" "33" "34" "35" "36" "37" "38" "39" "40"
            "41" "42" "43" "44" "45" "46" "47" "48" "49" "50"
        )
        token-id
    ))
)

(define-private (is-administrator)
    (or 
        (is-eq tx-sender CONTRACT-OWNER)
        (default-to false (map-get? administrators tx-sender))
    )
)

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

;; NFT Implementation Functions
(define-public (get-last-token-id)
    (ok (var-get last-token-id))
)

(define-public (get-token-uri (token-id uint))
    (match (map-get? tokens token-id)
        token (ok (some (get metadata-uri token)))
        (ok none)
    )
)

(define-public (get-owner (token-id uint))
    (ok (map-get? token-owners token-id))
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (let ((token (map-get? tokens token-id)))
        (asserts! (not (var-get contract-paused)) ERR-PAUSED)
        (asserts! (is-some token) ERR-TOKEN-NOT-FOUND)
        (asserts! (is-eq tx-sender (get owner (unwrap-panic token))) ERR-NOT-AUTHORIZED)
        
        (try! (begin-atomic))
        (map-set token-owners token-id recipient)
        (map-set tokens token-id 
            (merge (unwrap-panic token) { owner: recipient }))
        (unwrap! (end-atomic) ERR-REENTRANCY)
        
        (ok true)
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

(define-public (pause-contract)
    (begin
        (asserts! (is-administrator) ERR-NOT-AUTHORIZED)
        (var-set contract-paused true)
        (print {event: "contract-paused", admin: tx-sender})
        (ok true)
    )
)

(define-public (unpause-contract)
    (begin
        (asserts! (is-administrator) ERR-NOT-AUTHORIZED)
        (var-set contract-paused false)
        (print {event: "contract-unpaused", admin: tx-sender})
        (ok true)
    )
)

;; Core Subscription Functions
(define-public (mint-subscription (tier uint) (payment-token <ft-trait>))
    (let (
        (new-token-id (+ (var-get last-token-id) u1))
        (tier-info (unwrap! (map-get? tier-prices tier) ERR-INVALID-TIER))
        (current-time (unwrap-panic (get-block-info? time u0)))
    )
        (unwrap! (begin-atomic) ERR-REENTRANCY)
        (asserts! (not (var-get contract-paused)) ERR-PAUSED)
        
        ;; Process payment
        (try! (contract-call? payment-token transfer 
            (get price tier-info) 
            tx-sender 
            (as-contract tx-sender)
        ))
        
        ;; Create token
        (map-set tokens new-token-id {
            owner: tx-sender,
            tier: tier,
            expires-at: (+ current-time u2592000), ;; 30 days
            metadata-uri: (concat "ipfs://creatorpass/token-" (get-token-id-string new-token-id))
        })
        
        ;; Update state
        (map-set token-owners new-token-id tx-sender)
        (var-set last-token-id new-token-id)
        (var-set total-supply (+ (var-get total-supply) u1))
        
        (print {
            event: "subscription-minted",
            token-id: new-token-id,
            owner: tx-sender,
            tier: tier
        })
        
        (unwrap! (end-atomic) ERR-REENTRANCY)
        (ok new-token-id)
    )
)