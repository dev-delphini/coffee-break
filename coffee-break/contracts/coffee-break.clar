;; Coffee Break - Subscription Service Smart Contract
;; A simple recurring payment system for content access on Stacks blockchain

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_BALANCE (err u101))
(define-constant ERR_SUBSCRIPTION_NOT_FOUND (err u102))
(define-constant ERR_SUBSCRIPTION_EXPIRED (err u103))
(define-constant ERR_INVALID_AMOUNT (err u104))
(define-constant ERR_ALREADY_SUBSCRIBED (err u105))

;; Subscription tiers (prices in microSTX)
(define-constant BASIC_TIER_PRICE u5000000)    ;; 5 STX
(define-constant PREMIUM_TIER_PRICE u10000000) ;; 10 STX
(define-constant VIP_TIER_PRICE u20000000)     ;; 20 STX

;; Subscription duration (in blocks, ~10 minutes per block)
(define-constant SUBSCRIPTION_DURATION u4320) ;; ~30 days (4320 blocks)

;; Data structures
(define-map subscriptions
    { subscriber: principal }
    {
        tier: (string-ascii 10),
        start-block: uint,
        end-block: uint,
        auto-renewal: bool,
        total-paid: uint
    }
)

(define-map tier-prices
    { tier: (string-ascii 10) }
    { price: uint }
)

;; Contract balance tracking
(define-data-var contract-balance uint u0)
(define-data-var total-subscribers uint u0)

;; Initialize tier prices
(map-set tier-prices { tier: "basic" } { price: BASIC_TIER_PRICE })
(map-set tier-prices { tier: "premium" } { price: PREMIUM_TIER_PRICE })
(map-set tier-prices { tier: "vip" } { price: VIP_TIER_PRICE })

;; Helper functions
(define-private (get-tier-price (tier (string-ascii 10)))
    (default-to u0 (get price (map-get? tier-prices { tier: tier })))
)

(define-private (is-valid-tier (tier (string-ascii 10)))
    (or (is-eq tier "basic") (or (is-eq tier "premium") (is-eq tier "vip")))
)

(define-private (calculate-end-block (start-block uint))
    (+ start-block SUBSCRIPTION_DURATION)
)

;; Read-only functions
(define-read-only (get-subscription (subscriber principal))
    (map-get? subscriptions { subscriber: subscriber })
)

(define-read-only (is-subscription-active (subscriber principal))
    (match (get-subscription subscriber)
        subscription-data (>= (get end-block subscription-data) block-height)
        false
    )
)

(define-read-only (get-contract-balance)
    (var-get contract-balance)
)

(define-read-only (get-total-subscribers)
    (var-get total-subscribers)
)

(define-read-only (get-subscription-info (subscriber principal))
    (match (get-subscription subscriber)
        subscription-data
        {
            tier: (get tier subscription-data),
            active: (>= (get end-block subscription-data) block-height),
            blocks-remaining: (if (>= (get end-block subscription-data) block-height)
                                (- (get end-block subscription-data) block-height)
                                u0),
            auto-renewal: (get auto-renewal subscription-data),
            total-paid: (get total-paid subscription-data)
        }
        {
            tier: "",
            active: false,
            blocks-remaining: u0,
            auto-renewal: false,
            total-paid: u0
        }
    )
)

;; Public functions
(define-public (subscribe (tier (string-ascii 10)) (enable-auto-renewal bool))
    (let (
        (subscriber tx-sender)
        (price (get-tier-price tier))
        (existing-subscription (get-subscription subscriber))
    )
        (asserts! (is-valid-tier tier) ERR_INVALID_AMOUNT)
        (asserts! (> price u0) ERR_INVALID_AMOUNT)
        (asserts! (is-none existing-subscription) ERR_ALREADY_SUBSCRIBED)
        
        ;; Transfer STX from subscriber to contract
        (try! (stx-transfer? price subscriber (as-contract tx-sender)))
        
        ;; Update contract balance
        (var-set contract-balance (+ (var-get contract-balance) price))
        
        ;; Create subscription
        (map-set subscriptions
            { subscriber: subscriber }
            {
                tier: tier,
                start-block: block-height,
                end-block: (calculate-end-block block-height),
                auto-renewal: enable-auto-renewal,
                total-paid: price
            }
        )
        
        ;; Increment subscriber count
        (var-set total-subscribers (+ (var-get total-subscribers) u1))
        
        (ok true)
    )
)

(define-public (renew-subscription)
    (let (
        (subscriber tx-sender)
        (subscription-data (unwrap! (get-subscription subscriber) ERR_SUBSCRIPTION_NOT_FOUND))
        (tier (get tier subscription-data))
        (price (get-tier-price tier))
        (current-end-block (get end-block subscription-data))
        (new-end-block (+ current-end-block SUBSCRIPTION_DURATION))
    )
        ;; Transfer STX from subscriber to contract
        (try! (stx-transfer? price subscriber (as-contract tx-sender)))
        
        ;; Update contract balance
        (var-set contract-balance (+ (var-get contract-balance) price))
        
        ;; Update subscription
        (map-set subscriptions
            { subscriber: subscriber }
            {
                tier: tier,
                start-block: (get start-block subscription-data),
                end-block: new-end-block,
                auto-renewal: (get auto-renewal subscription-data),
                total-paid: (+ (get total-paid subscription-data) price)
            }
        )
        
        (ok true)
    )
)

(define-public (cancel-subscription)
    (let (
        (subscriber tx-sender)
        (subscription-data (unwrap! (get-subscription subscriber) ERR_SUBSCRIPTION_NOT_FOUND))
    )
        ;; Update subscription to disable auto-renewal
        (map-set subscriptions
            { subscriber: subscriber }
            (merge subscription-data { auto-renewal: false })
        )
        
        (ok true)
    )
)

(define-public (upgrade-subscription (new-tier (string-ascii 10)))
    (let (
        (subscriber tx-sender)
        (subscription-data (unwrap! (get-subscription subscriber) ERR_SUBSCRIPTION_NOT_FOUND))
        (current-tier (get tier subscription-data))
        (current-price (get-tier-price current-tier))
        (new-price (get-tier-price new-tier))
        (price-difference (- new-price current-price))
    )
        (asserts! (is-valid-tier new-tier) ERR_INVALID_AMOUNT)
        (asserts! (> new-price current-price) ERR_INVALID_AMOUNT)
        (asserts! (is-subscription-active subscriber) ERR_SUBSCRIPTION_EXPIRED)
        
        ;; Transfer price difference
        (try! (stx-transfer? price-difference subscriber (as-contract tx-sender)))
        
        ;; Update contract balance
        (var-set contract-balance (+ (var-get contract-balance) price-difference))
        
        ;; Update subscription tier
        (map-set subscriptions
            { subscriber: subscriber }
            (merge subscription-data { 
                tier: new-tier,
                total-paid: (+ (get total-paid subscription-data) price-difference)
            })
        )
        
        (ok true)
    )
)

;; Owner functions
(define-public (withdraw-funds (amount uint) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (<= amount (var-get contract-balance)) ERR_INSUFFICIENT_BALANCE)
        
        ;; Transfer STX from contract to recipient
        (try! (as-contract (stx-transfer? amount tx-sender recipient)))
        
        ;; Update contract balance
        (var-set contract-balance (- (var-get contract-balance) amount))
        
        (ok true)
    )
)

(define-public (update-tier-price (tier (string-ascii 10)) (new-price uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (is-valid-tier tier) ERR_INVALID_AMOUNT)
        (asserts! (> new-price u0) ERR_INVALID_AMOUNT)
        
        (map-set tier-prices { tier: tier } { price: new-price })
        (ok true)
    )
)

;; Auto-renewal function (to be called by external service or users)
(define-public (process-auto-renewal (subscriber principal))
    (let (
        (subscription-data (unwrap! (get-subscription subscriber) ERR_SUBSCRIPTION_NOT_FOUND))
        (tier (get tier subscription-data))
        (price (get-tier-price tier))
        (auto-renewal (get auto-renewal subscription-data))
        (current-end-block (get end-block subscription-data))
    )
        (asserts! auto-renewal ERR_NOT_AUTHORIZED)
        (asserts! (<= current-end-block block-height) ERR_NOT_AUTHORIZED)
        
        ;; Transfer STX from subscriber to contract
        (try! (stx-transfer? price subscriber (as-contract tx-sender)))
        
        ;; Update contract balance
        (var-set contract-balance (+ (var-get contract-balance) price))
        
        ;; Extend subscription
        (map-set subscriptions
            { subscriber: subscriber }
            {
                tier: tier,
                start-block: (get start-block subscription-data),
                end-block: (+ current-end-block SUBSCRIPTION_DURATION),
                auto-renewal: auto-renewal,
                total-paid: (+ (get total-paid subscription-data) price)
            }
        )
        
        (ok true)
    )
)